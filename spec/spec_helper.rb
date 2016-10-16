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

require 'rspec'
require 'rspec_command'
require 'simplecov'
require 'git'
require 'shellwords'

# Check for coverage stuffs
if ENV['CODECOV_TOKEN'] || ENV['TRAVIS']
  require 'codecov'
  SimpleCov.formatter = SimpleCov::Formatter::Codecov
end

SimpleCov.start do
  # Don't get coverage on the test cases themselves.
  add_filter '/spec/'
  add_filter '/test/'
  # Codecov doesn't automatically ignore vendored files.
  add_filter '/vendor/'
end

require 'dco'

module DcoSpecHelper
  extend RSpec::SharedContext

  def dco_command *args
    cwd = Dir.pwd
    begin
      Dir.chdir(temp_path)
      capture_output do
        args = Shellwords.split(args.first) if args.length == 1 && args.first.is_a?(String)
        Dco::CLI.start(args)
      end
    ensure
      Dir.chdir(cwd)
    end
  rescue Exception => e
    status  = e.is_a?(SystemExit) ? e.status : 1
    e.output_so_far.define_singleton_method(:exitstatus) { status }
    e.output_so_far
  end

  def git_init(name: 'Alan Smithee', email: 'asmithee@example.com')
    command "git init && git config user.name \"#{name}\" && git config user.email \"#{email}\""
  end

  let(:repo) { Git.open(temp_path) }

  module ClassMethods
    def dco_command *args
      subject { dco_command(*args) }
    end

    def git_init(*args)
      before { git_init(*args) }
    end
  end
end

RSpec.configure do |config|
  # Basic configuraiton
  config.run_all_when_everything_filtered = true
  config.filter_run(:focus)

  # Run specs in random order to surface order dependencies. If you find an
  # order dependency and want to debug it, you can fix the order by providing
  # the seed, which is printed after each run.
  #     --seed 1234
  config.order = 'random'

  config.include RSpecCommand

  config.include DcoSpecHelper
  config.extend DcoSpecHelper::ClassMethods
end
