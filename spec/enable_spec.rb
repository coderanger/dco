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

describe 'dco enable' do
  # The most recent commit object.
  subject { repo.log.first }

  context 'without a git repository' do
    dco_command 'enable -y'

    it do
      expect(subject.exitstatus).to eq 1
      expect(subject.stdout).to eq ''
      expect(subject.stderr).to match /does not appear to be a git repository$/
    end
  end # /context without a git repository

  context 'with an unwritable git repository' do
    git_init
    before { File.chmod(00544, File.join(temp_path, '.git')) }
    dco_command 'enable -y'
    after { File.chmod(00744, File.join(temp_path, '.git')) }

    it do
      expect(subject.exitstatus).to eq 1
      expect(subject.stdout).to eq ''
      expect(subject.stderr).to match /^Git repository at.*? is read-only$/
    end
  end # /context with an unwritable git repository

  context 'with an existing commit-msg script' do
    git_init
    file '.git/hooks/commit-msg', 'SOMETHING ELSE'
    dco_command 'enable -y'

    it do
      expect(subject.exitstatus).to eq 1
      expect(subject.stdout).to eq ''
      expect(subject.stderr).to match /^commit-msg hook already exists, not overwriting$/
    end
  end # /context with an existing commit-msg script

  context 'with a normal commit' do
    git_init
    file 'testing'
    before do
      dco_command 'enable -y'
      command 'git add testing'
      command 'git commit -m "test commit"'
    end

    its(:message) { is_expected.to eq "test commit\n\nSigned-off-by: Alan Smithee <asmithee@example.com>" }
  end # /context with a normal commit

  context 'with a signed-off commit' do
    git_init
    file 'testing'
    before do
      dco_command 'enable -y'
      command 'git add testing'
      command 'git commit -s -m "test commit"'
    end

    its(:message) { is_expected.to eq "test commit\n\nSigned-off-by: Alan Smithee <asmithee@example.com>" }
  end # /context with a signed-off commit

  context 'with enable called twice' do
    git_init
    file 'testing'
    before do
      dco_command 'enable -y'
      dco_command 'enable -y'
      command 'git add testing'
      command 'git commit -m "test commit"'
    end

    its(:message) { is_expected.to eq "test commit\n\nSigned-off-by: Alan Smithee <asmithee@example.com>" }
  end # /context with enable called twice

  context 'without -y' do
    git_init
    dco_command 'enable'

    it do
      expect(subject.exitstatus).to eq 1
      expect(subject.stderr).to eq "Not enabling auto-sign-off without approval\n"
    end
  end # /context without -y
end
