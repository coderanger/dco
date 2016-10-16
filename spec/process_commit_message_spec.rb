#
# Copyright 2016, Noah Kantrowitz
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'spec_helper'

describe 'dco process_commit_message' do
  around do |ex|
    begin
      ENV['GIT_COMMIT'] = 'abcd123'
      ENV['GIT_AUTHOR_NAME'] = 'Alan Smithee'
      ENV['GIT_AUTHOR_EMAIL'] = 'asmithee@example.com'
      ex.run
    ensure
      ENV.delete('GIT_COMMIT')
      ENV.delete('GIT_AUTHOR_NAME')
      ENV.delete('GIT_AUTHOR_EMAIL')
    end
  end

  context 'hook mode' do
    dco_command 'process_commit_message msg'

    RSpec.shared_examples 'process_commit_message hook mode' do |input, output|
      file 'msg', input

      it do
        expect(subject.exitstatus).to eq 0
        expect(subject.stdout).to eq ''
        expect(subject.stderr).to eq ''
        expect(IO.read(File.join(temp_path, 'msg'))).to eq output
      end
    end

    context 'with a normal commit' do
      it_behaves_like 'process_commit_message hook mode', "test commit\n", "test commit\n\nSigned-off-by: Alan Smithee <asmithee@example.com>\n"
    end # /context with a normal commit

    context 'with no trailing newline' do
      it_behaves_like 'process_commit_message hook mode', "test commit", "test commit\n\nSigned-off-by: Alan Smithee <asmithee@example.com>\n"
    end # /context with no trailing newline

    context 'with existing sign-off' do
      it_behaves_like 'process_commit_message hook mode', "test commit\n\nSigned-off-by: Someone Else <other@example.com>\n", "test commit\n\nSigned-off-by: Someone Else <other@example.com>\n"
    end # /context with existing sign-off

    context 'with two existing sign-offs' do
      it_behaves_like 'process_commit_message hook mode', "test commit\n\nSigned-off-by: Alan Smithee <asmithee@example.com>\nSigned-off-by: Someone Else <other@example.com>\n", "test commit\n\nSigned-off-by: Alan Smithee <asmithee@example.com>\nSigned-off-by: Someone Else <other@example.com>\n"
    end # /context with two existing sign-offs
  end # /context hook mode

  context 'filter mode' do
    let(:input) { '' }
    let(:git_ident) { {} }
    let(:stdin) { double('STDIN', read: input) }
    before do
      # Use a let variable instead of calling git_init again in a later before
      # block because we need to all command running before the STDIN stub.
      git_init git_ident
      stub_const('STDIN', stdin)
    end

    context 'with a normal commit' do
      let(:input) { "test commit\n" }
      dco_command 'process_commit_message'

      it do
        expect(subject.exitstatus).to eq 0
        expect(subject.stdout).to eq "test commit\n\nSigned-off-by: Alan Smithee <asmithee@example.com>\n"
        expect(subject.stderr).to eq ''
      end
    end # /context with a normal commit

    context 'with existing sign-off' do
      let(:input) { "test commit\n\nSigned-off-by: Someone Else <other@example.com>\n" }
      dco_command 'process_commit_message'

      it do
        expect(subject.exitstatus).to eq 0
        expect(subject.stdout).to eq "test commit\n\nSigned-off-by: Someone Else <other@example.com>\n"
        expect(subject.stderr).to eq ''
      end
    end # /context with existing sign-off

    context 'with --behalf' do
      let(:input) { "test commit\n" }
      let(:git_ident) { {name: 'Someone Else', email: 'other@example.com'} }
      dco_command 'process_commit_message --behalf http://example.com/'

      it do
        expect(subject.exitstatus).to eq 0
        expect(subject.stdout).to eq "test commit\n\nSigned-off-by: Alan Smithee <asmithee@example.com>\nSign-off-executed-by: Someone Else <other@example.com>\nApproved-at: http://example.com/\n"
        expect(subject.stderr).to eq ''
      end
    end # /context with --behalf

    context 'with someone elses commit' do
      let(:input) { "test commit\n" }
      let(:git_ident) { {name: 'Someone Else', email: 'other@example.com'} }
      dco_command 'process_commit_message'

      it do
        expect(subject.exitstatus).to eq 1
        expect(subject.stdout).to eq "test commit\n"
        expect(subject.stderr).to eq "Author mismatch on commit abcd123: asmithee@example.com vs other@example.com\n"
      end
    end # /context with someone elses commit

    context 'with --repo' do
      let(:input) { "test commit\n" }
      subject { dco_command "process_commit_message --repo '#{temp_path}'" }

      it do
        expect(subject.exitstatus).to eq 0
        expect(subject.stdout).to eq "test commit\n\nSigned-off-by: Alan Smithee <asmithee@example.com>\n"
        expect(subject.stderr).to eq ''
      end
    end # /context with --repo
  end # /context filter mode
end
