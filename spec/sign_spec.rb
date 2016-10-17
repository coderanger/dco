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

describe 'dco sign' do
  # Create a branch structure for all tests.
  git_init
  file 'testing', 'one'
  before do
    cmds = [
      'git add testing',
      'git commit -m "first commit"',
      'echo two > testing',
      'git commit -a -m "second commit"',
      'git checkout -b mybranch',
    ]
    command cmds.join(' && ')
  end

  context 'with no commits in the branch' do
    dco_command 'sign -y mybranch'

    it do
      expect(subject.exitstatus).to eq 1
      expect(subject.stderr).to eq "Branch mybranch has no commits which require sign-off\n"
    end
  end # /context with no commits in the branch

  context 'with one commit in the branch' do
    before do
      command 'echo three > testing && git commit -a -m "first branch commit"'
    end
    dco_command 'sign -y mybranch'

    it do
      expect(subject.exitstatus).to eq 0
      expect(subject.stdout).to match /^Developer's Certificate of Origin 1\.1$/
      expect(subject.stdout).to match /^Going to sign-off the following commits:\n\* \h{7} Alan Smithee <asmithee@example\.com> first branch commit$/
      expect(repo.log[0].message).to eq "first branch commit\n\nSigned-off-by: Alan Smithee <asmithee@example.com>"
      expect(repo.log[1].message).to eq "second commit"
      expect(repo.log[2].message).to eq "first commit"
    end
  end # /context with one commit in the branch

  context 'with one commit in the branch without -y' do
    before do
      command 'echo three > testing && git commit -a -m "first branch commit"'
    end
    dco_command 'sign mybranch'

    it do
      expect(subject.exitstatus).to eq 1
      expect(subject.stderr).to eq "Not signing off on commits without approval\n"
    end
  end # /context with one commit in the branch without -y

  context 'with two commits in the branch' do
    before do
      command 'echo three > testing && git commit -a -m "first branch commit" && echo four > testing && git commit -a -m "second branch commit"'
    end
    dco_command 'sign -y mybranch'

    it do
      expect(subject.exitstatus).to eq 0
      expect(subject.stdout).to match /^Developer's Certificate of Origin 1\.1$/
      expect(subject.stdout).to match /^Going to sign-off the following commits:\n\* \h{7} Alan Smithee <asmithee@example\.com> second branch commit\n\* \h{7} Alan Smithee <asmithee@example\.com> first branch commit$/
      expect(repo.log[0].message).to eq "second branch commit\n\nSigned-off-by: Alan Smithee <asmithee@example.com>"
      expect(repo.log[1].message).to eq "first branch commit\n\nSigned-off-by: Alan Smithee <asmithee@example.com>"
      expect(repo.log[2].message).to eq "second commit"
      expect(repo.log[3].message).to eq "first commit"
    end
  end # /context with two commits in the branch

  context 'with a branch that has a merge commit' do
    before do
      command('echo three > other && ' \
        'git add other && ' \
        'git commit -a -m "first branch commit" && ' \
        'git checkout master && ' \
        'echo three > testing && ' \
        'git commit -a -m "third commit" && ' \
        'git checkout mybranch && ' \
        'git merge master && ' \
        'echo four > other && ' \
        'git commit -a -m "second branch commit"')
    end
    dco_command 'sign -y mybranch'

    it do
      expect(subject.exitstatus).to eq 0
      expect(subject.stdout).to match /^Developer's Certificate of Origin 1\.1$/
      expect(subject.stdout).to match /^Going to sign-off the following commits:\n\* \h{7} Alan Smithee <asmithee@example\.com> second branch commit\n\* \h{7} Alan Smithee <asmithee@example\.com> Merge branch 'master' into mybranch\n\* \h{7} Alan Smithee <asmithee@example\.com> first branch commit$/
      # Ordering is unstable because of the merge.
      commits = repo.log.map {|c| c.message }
      expect(commits.size).to eq 6
      expect(commits).to include "second branch commit\n\nSigned-off-by: Alan Smithee <asmithee@example.com>"
      expect(commits).to include "Merge branch 'master' into mybranch\n\nSigned-off-by: Alan Smithee <asmithee@example.com>"
      expect(commits).to include "first branch commit\n\nSigned-off-by: Alan Smithee <asmithee@example.com>"
      expect(commits).to include "third commit"
      expect(commits).to include "second commit"
      expect(commits).to include "first commit"
    end
  end # /context with a branch that has a merge commit

  context 'with behalf mode enabled' do
    before do
      command 'echo three > testing && git commit -a -m "first branch commit" && echo four > testing && git commit -a -m "second branch commit"'
      git_init(name: 'Commiter McCommiterface', email: 'other@example.com')
    end
    dco_command 'sign -y mybranch -b https://github.com/chef/chef/pulls/1234'

    it do
      expect(subject.exitstatus).to eq 0
      expect(subject.stdout).to_not match /^Developer's Certificate of Origin 1\.1$/
      expect(subject.stdout).to match /^Going to sign-off the following commits:\n\* \h{7} Alan Smithee <asmithee@example\.com> second branch commit\n\* \h{7} Alan Smithee <asmithee@example\.com> first branch commit$/
      expect(repo.log[0].message).to eq "second branch commit\n\nSigned-off-by: Alan Smithee <asmithee@example.com>\nSign-off-executed-by: Commiter McCommiterface <other@example.com>\nApproved-at: https://github.com/chef/chef/pulls/1234"
      expect(repo.log[1].message).to eq "first branch commit\n\nSigned-off-by: Alan Smithee <asmithee@example.com>\nSign-off-executed-by: Commiter McCommiterface <other@example.com>\nApproved-at: https://github.com/chef/chef/pulls/1234"
      expect(repo.log[2].message).to eq "second commit"
      expect(repo.log[3].message).to eq "first commit"
    end
  end # /context with behalf mode enabled

  context 'with someone elses commits' do
    before do
      command 'echo three > testing && git commit -a -m "first branch commit" && echo four > testing && git commit -a -m "second branch commit"'
      git_init(name: 'Commiter McCommiterface', email: 'other@example.com')
    end
    dco_command 'sign -y mybranch'

    it do
      expect(subject.exitstatus).to eq 1
      expect(subject.stderr).to eq "Branch mybranch contains commits not authored by you. Please use the --behalf flag when signing off for another contributor\n"
    end
  end # /context with someone elses commits

  context 'with an invalid branch' do
    dco_command 'sign -y master'

    it do
      expect(subject.exitstatus).to eq 1
      expect(subject.stderr).to eq "Cannot use master for both the base and target branch\n"
    end
  end # /context with an invalid branch

  context 'with an implicit branch' do
    before do
      command 'echo three > testing && git commit -a -m "first branch commit"'
    end
    dco_command 'sign -y'

    it do
      expect(subject.exitstatus).to eq 0
      expect(subject.stdout).to match /^Developer's Certificate of Origin 1\.1$/
      expect(subject.stdout).to match /^Going to sign-off the following commits:\n\* \h{7} Alan Smithee <asmithee@example\.com> first branch commit$/
      expect(repo.log[0].message).to eq "first branch commit\n\nSigned-off-by: Alan Smithee <asmithee@example.com>"
      expect(repo.log[1].message).to eq "second commit"
      expect(repo.log[2].message).to eq "first commit"
    end
  end # /context with an implicit branch

  context 'with an implicit invalid branch' do
    before { command 'git checkout master' }
    dco_command 'sign -y'

    it do
      expect(subject.exitstatus).to eq 1
      expect(subject.stderr).to eq "Cannot use master for both the base and target branch\n"
    end
  end # /context with an implicit invalid branch

  context 'with an existing backup pointer' do
    before do
      command 'echo three > testing && git commit -a -m "first branch commit"'
      dco_command 'sign -y mybranch'
      command 'echo four > testing && git commit -a -m "second branch commit"'
    end
    dco_command 'sign -y mybranch'

    it do
      expect(subject.exitstatus).to eq 0
      expect(subject.stdout).to match /^Developer's Certificate of Origin 1\.1$/
      expect(subject.stdout).to match /^Going to sign-off the following commits:\n\* \h{7} Alan Smithee <asmithee@example\.com> second branch commit$/
      expect(repo.log[0].message).to eq "second branch commit\n\nSigned-off-by: Alan Smithee <asmithee@example.com>"
      expect(repo.log[1].message).to eq "first branch commit\n\nSigned-off-by: Alan Smithee <asmithee@example.com>"
      expect(repo.log[2].message).to eq "second commit"
      expect(repo.log[3].message).to eq "first commit"
    end
  end # /context with an existing backup pointer

  context 'with an existing backup pointer without -y' do
    before do
      command 'echo three > testing && git commit -a -m "first branch commit"'
      dco_command 'sign -y mybranch'
      command 'echo four > testing && git commit -a -m "second branch commit"'
    end
    dco_command 'sign mybranch'

    it do
      expect(subject.exitstatus).to eq 1
      expect(subject.stderr).to eq "Backup ref present, not continuing\n"
    end
  end # /context with an existing backup pointer without -y

  context 'with uncommitted changes' do
    before do
      command 'echo three > testing && git commit -a -m "first branch commit" && echo four > testing'
    end
    dco_command 'sign -y mybranch'

    it do
      puts("UNCOMMITTED CHANGES OUTPUT #{subject.stdout.inspect} #{subject.stderr.inspect}")
      puts("STASH FILE? #{Dir.entries(File.join(temp_path, '.git/logs/refs')).inspect}")
      puts(File.stat(File.join(temp_path, '.git/logs/refs/stash')).inspect)
      puts("HANDLE #{command("C:\\handle.exe stash").stdout}")
      # For some reason, windows leaves this file here?
      stash_path = File.join(temp_path, '.git/logs/refs/stash')
      if File.exist?(stash_path)
        File.rename(stash_path, stash_path+'.bak')
        File.unlink(stash_path+'.bak')
      end

      expect(subject.exitstatus).to eq 0
      expect(subject.stdout).to match /^Stashing uncommited changes before continuing$/
      expect(IO.read(File.join(temp_path, 'testing'))).to eq "four\n"
    end
  end # /context with uncommitted changes
end
