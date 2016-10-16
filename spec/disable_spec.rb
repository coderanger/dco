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

describe 'dco disable' do
  # The most recent commit object.
  subject { repo.log.first }

  context 'with a normal commit' do
    git_init
    file 'testing'
    before do
      dco_command 'enable -y'
      dco_command 'disable'
      command 'git add testing'
      command 'git commit -m "test commit"'
    end

    its(:message) { is_expected.to eq "test commit" }
  end # /context with a normal commit

  context 'with disable called twice' do
    git_init
    file 'testing'
    before do
      dco_command 'enable -y'
      dco_command 'disable'
      dco_command 'disable'
      command 'git add testing'
      command 'git commit -m "test commit"'
    end

    its(:message) { is_expected.to eq "test commit" }
  end # /context with disable called twice

  context 'with an external commit-msg script' do
    git_init
    file '.git/hooks/commit-msg', 'SOMETHING ELSE'
    dco_command 'disable'

    it do
      expect(subject.exitstatus).to eq 1
      expect(subject.stdout).to eq ''
      expect(subject.stderr).to match /^commit-msg hook is external, not removing$/
    end
  end # /context with an existing commit-msg script
end
