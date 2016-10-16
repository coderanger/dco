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

describe 'baseline' do
  # The most recent commit object.
  subject { repo.log.first }

  # Check that the test harness is working.
  git_init
  file 'testing'
  before do
    command 'git add testing'
    command 'git commit -m "harness test"'
  end

  its(:message) { is_expected.to eq 'harness test' }
  its('author.name') { is_expected.to eq 'Alan Smithee' }
  its('author.email') { is_expected.to eq 'asmithee@example.com' }
end
