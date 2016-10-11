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

require 'thor'


module Dco
  class CLI < Thor
    # Because this isn't the default and exit statuses are what the cool kids do.
    def self.exit_on_failure?
      true
    end

    # Internal command used by the git hook to implement the processing logic.
    # This is done in Ruby because writing it to work on all platforms in Bash
    # seems unfun.
    desc 'process_commit_msg', 'process a git commit message to add DCO signoff', hide: true
    def process_commit_message(tmp_path)
      commit_msg = IO.read(tmp_path)
      unless commit_msg =~ /^Signed-off-by:/m
        commit_msg << "\n" unless commit_msg.end_with?("\n")
        commit_msg << "\nSigned-off-by: asdf\n"
        IO.write(tmp_path, commit_msg)
      end
    end

    # Full text of the DCO.
    # @api private
    DCO_TEXT = <<-EOH
Developer Certificate of Origin
Version 1.1

Copyright (C) 2004, 2006 The Linux Foundation and its contributors.
1 Letterman Drive
Suite D4700
San Francisco, CA, 94129

Everyone is permitted to copy and distribute verbatim copies of this
license document, but changing it is not allowed.


Developer's Certificate of Origin 1.1

By making a contribution to this project, I certify that:

(a) The contribution was created in whole or in part by me and I
    have the right to submit it under the open source license
    indicated in the file; or

(b) The contribution is based upon previous work that, to the best
    of my knowledge, is covered under an appropriate open source
    license and I have the right under that license to submit that
    work with modifications, whether created in whole or in part
    by me, under the same open source license (unless I am
    permitted to submit under a different license), as indicated
    in the file; or

(c) The contribution was provided directly to me by some other
    person who certified (a), (b) or (c) and I have not modified
    it.

(d) I understand and agree that this project and the contribution
    are public and that a record of the contribution (including all
    personal information I submit with it, including my sign-off) is
    maintained indefinitely and may be redistributed consistent with
    this project or the open source license(s) involved.
EOH

    # Git commit-msg hook script to automatically apply DCO.
    # @api private
    HOOK_SCRIPT = <<-EOH
#!/bin/sh
# INSTALLED BY DCO GEM
export #{ENV.select {|key, value| key =~ /^(bundle_|ruby|gem_)/i }.map {|key, value| "#{key}=#{value.inspect}"}.join(' ')}
#{Thor::Util.ruby_command} #{$0} process_commit_message $1
exit $?
EOH

    desc 'enable', 'Enable auto-sign-off for this repository'
    def enable
      assert_repo!
      unless our_hook?
        raise Thor::Error.new('commit-msg hook already exists, not overwriting')
      end
      unless yes?("Do you, #{'name'}, certify that all future commits to this repository will be under the terms of the Developer Certificate of Origin? [yes/no]")
        raise Thor::Error.new('Not enabling auto-sign-off')
      end
      IO.write(hook_path, HOOK_SCRIPT)
      # 755 is what the defaults from `git init` use so probably good enough.
      File.chmod(00755, hook_path)
      say('DCO auto-sign-off enabled', :green)
    end

    desc 'disable', 'Disable auto-sign-off for this repository'
    def disable
      assert_repo!
      unless our_hook?
        raise Thor::Error.new('commit-msg hook is external, not removing')
      end
      File.unlink(hook_path)
      say('DCO auto-sign-off disabled', :green)
    end

    private

    # Check that we are in a git repo that we have write access to.
    #
    # @api private
    # @return [void]
    def assert_repo!
      unless Dir.exist?('.git')
        raise Thor::Error.new("#{Dir.pwd} does not appear to be a git repository")
      end
      unless File.writable?('.git')
        raise Thor::Error.new("Can't open #{Dir.pwd}/.git for writing")
      end
    end

    # Find the path to the commit-msg hook script.
    #
    # @api private
    # @return [String]
    def hook_path
      File.join(Dir.pwd, '.git', 'hooks', 'commit-msg')
    end

    # Check if we are in control of the commit-msg hook.
    #
    # @api private
    # @return [Boolean]
    def our_hook?
      path = hook_path
      !File.exist?(path) || IO.read(path).include?('INSTALLED BY DCO GEM')
    end
  end
end
