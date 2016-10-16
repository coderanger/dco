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

describe 'dco check' do
  # Create a branch structure for all tests.
  git_init
  file 'testing', 'one'
  before do
    cmds = [
      'git add testing',
      'git commit -s -m "first commit"',
      'echo two > testing',
      'git commit -s -a -m "second commit"',
      'git checkout -b mybranch',
    ]
    command cmds.join(' && ')
  end
  dco_command 'check mybranch'

  context 'with no commits in the branch' do
    it do
      expect(subject.exitstatus).to eq 0
      expect(subject.stdout).to eq "All commits are signed off\n"
    end
  end # /context with no commits in the branch

  context 'with one signed commit in the branch' do
    before do
      command 'echo three > testing && git commit -s -a -m "first branch commit"'
    end

    it do
      expect(subject.exitstatus).to eq 0
      expect(subject.stdout).to eq "All commits are signed off\n"
    end
  end # /context with one signed commit in the branch

  context 'with one unsigned commit in the branch' do
    before do
      command 'echo three > testing && git commit -a -m "first branch commit" && echo four > testing && git commit -s -a -m "second branch commit"'
    end

    it do
      expect(subject.exitstatus).to eq 1
      expect(subject.stdout).to match /^N \h{7} Alan Smithee <asmithee@example.com> first branch commit$/
    end
  end # /context with one unsigned commit in the branch

  context 'with two signed commits in the branch' do
    before do
      command 'echo three > testing && git commit -s -a -m "first branch commit" && echo four > testing && git commit -s -a -m "second branch commit"'
    end

    it do
      expect(subject.exitstatus).to eq 0
      expect(subject.stdout).to eq "All commits are signed off\n"
    end
  end # /context with two signed commits in the branch

  context 'with an implicit branch' do
    before do
      command 'echo three > testing && git commit -a -m "first branch commit" && echo four > testing && git commit -s -a -m "second branch commit"'
    end
    dco_command 'check'

    it do
      expect(subject.exitstatus).to eq 1
      expect(subject.stdout).to match /^N \h{7} Alan Smithee <asmithee@example.com> first branch commit$/
    end
  end # /context with an implicit branch

  context 'with a branch that has a merge commit' do
    before do
      command('echo three > other && ' \
        'git add other && ' \
        'git commit -s -a -m "first branch commit" && ' \
        'git checkout master && ' \
        'echo three > testing && ' \
        'git commit -a -m "third commit" && ' \
        'git checkout mybranch && ' \
        'git merge master && ' \
        'echo four > other && ' \
        'git commit -a -m "second branch commit"')
    end

    it do
      expect(subject.exitstatus).to eq 1
      expect(subject.stdout).to match /^N \h{7} Alan Smithee <asmithee@example.com> second branch commit$/
      expect(subject.stdout).to_not match /^N \h{7} Alan Smithee <asmithee@example.com> third commit$/
      # TODO What should the check behavior on merge commits be? https://github.com/coderanger/dco/issues/1
    end
  end # /context with a branch that has a merge commit

  context 'with --quiet' do
    dco_command 'check --quiet'

    context 'with no bad commits' do
      before { command 'echo three > testing && git commit -s -a -m "first branch commit"' }

      it do
        expect(subject.exitstatus).to eq 0
        expect(subject.stdout).to eq ''
        expect(subject.stderr).to eq ''
      end
    end # /context with no bad commits

    context 'with bad commits' do
      before { command 'echo three > testing && git commit -a -m "first branch commit"' }

      it do
        expect(subject.exitstatus).to eq 1
        expect(subject.stdout).to eq ''
        expect(subject.stderr).to eq ''
      end
    end # /context with bad commits
  end # /context with --quiet

  context 'with the master branch' do
    before do
      command('echo three > other && ' \
        'git add other && ' \
        'git commit -s -a -m "first branch commit" && ' \
        'git checkout master && ' \
        'echo three > testing && ' \
        'git commit -a -m "third commit"')
    end
    dco_command 'check master'

    it do
      expect(subject.exitstatus).to eq 1
      expect(subject.stdout).to match /^N \h{7} Alan Smithee <asmithee@example.com> third commit$/
      expect(subject.stdout).to_not match /^N \h{7} Alan Smithee <asmithee@example.com> first branch commit$/
    end
  end # /context with the master branch

  context 'with an author mismatch' do
    file 'msg', "first branch commit\n\nSigned-off-by: Commiter McCommiterface <other@example.com>\n"
    before do
      command 'echo three > testing && git commit -a -F msg'
    end

    it do
      expect(subject.exitstatus).to eq 1
      expect(subject.stdout).to match /^M \h{7} Alan Smithee <asmithee@example.com> first branch commit$/
    end

    context 'with --allow-author-mismatch' do
      dco_command 'check --allow-author-mismatch mybranch'

    it do
      expect(subject.exitstatus).to eq 0
      expect(subject.stdout).to eq "All commits are signed off\n"
    end

    end # /context with --allow-author-mismatch
  end # /context with an author mismatch
end
