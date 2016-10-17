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

require 'shellwords'

require 'git'
require 'thor'


module Dco
  class CLI < Thor
    # Because this isn't the default and exit statuses are what the cool kids do.
    def self.exit_on_failure?
      true
    end

    # Fix the basename display in ChefDK.
    #
    # @api private
    # @return [String]
    def self.basename
      ret = super
      if ret == 'chef'
        'chef dco'
      else
        ret
      end
    end

    no_commands do
      # Return the path for the git repository we will process. Defaults to the
      # current working directory.
      #
      # @return [String]
      def repo_path
        @repo_path || Dir.pwd
      end

      # Set a new path for the git repository.
      #
      # @param val [String] Path
      # @return [void]
      def repo_path=(val)
        @repo_path = val
        # Force things to reload.
        @repo = nil
        @repo_config = nil
      end
    end

    # Internal command used by the git hook to implement the processing logic.
    # This is done in Ruby because writing it to work on all platforms in Bash
    # seems unfun.
    #
    # Design note: this should try as hard as possible to be fast, especially
    # in hook mode as it adds overhead time to every commit there. Currently
    # it should only have to touch the filesystem to read/write the message,
    # when in hook mode. For filter mode, it does need to load the git config
    # if using --behalf.
    desc 'process_commit_message', 'process a git commit message to add DCO signoff', hide: true
    options behalf: :string, repo: :string
    def process_commit_message(tmp_path=nil)
      # Set the repo path if passed.
      self.repo_path = options[:repo] if options[:repo]
      # If a path is passed use it as a tmpfile, otherwise assume filter mode.
      commit_msg = tmp_path ? IO.read(tmp_path) : STDIN.read
      unless has_sign_off?(commit_msg)
        # If we're in filter mode and not on-behalf-of, do a final check of the author.
        if !tmp_path && !options[:behalf] && ENV['GIT_AUTHOR_EMAIL'] != repo_config['user.email']
          # Something went wrong, refuse to rewrite.
          STDOUT.write(commit_msg)
          raise Thor::Error.new("Author mismatch on commit #{ENV['GIT_COMMIT']}: #{ENV['GIT_AUTHOR_EMAIL']} vs #{repo_config['user.email']}")
        end
        commit_msg << "\n" unless commit_msg.end_with?("\n")
        commit_msg << "\nSigned-off-by: #{ENV['GIT_AUTHOR_NAME']} <#{ENV['GIT_AUTHOR_EMAIL']}>\n"
        if options[:behalf]
          # This requires loading the actual repo config, which is slower.
          commit_msg << "Sign-off-executed-by: #{git_identity}\n"
          commit_msg << "Approved-at: #{options[:behalf]}\n"
        end
        IO.write(tmp_path, commit_msg) if tmp_path
      end
      # Always display the replacement commit message if we're in filter mode.
      STDOUT.write(commit_msg) unless tmp_path
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
#{Thor::Util.ruby_command} #{File.expand_path('../../../bin/dco', __FILE__)} process_commit_message $1
exit $?
EOH

    # Path to the git hook script.
    # @api private
    HOOK_PATH = '.git/hooks/commit-msg'

    desc 'enable', 'Enable auto-sign-off for this repository'
    option :yes, aliases: 'y', type: :boolean, desc: 'Agree to all prompts'
    def enable
      assert_repo!
      unless our_hook?
        raise Thor::Error.new('commit-msg hook already exists, not overwriting')
      end
      say("#{DCO_TEXT}\n\n", :yellow)
      unless confirm?("Do you, #{git_identity}, certify that all future commits to this repository will be under the terms of the Developer Certificate of Origin? [yes/no]")
        raise Thor::Error.new('Not enabling auto-sign-off without approval')
      end
      IO.write(HOOK_PATH, HOOK_SCRIPT)
      # 755 is what the defaults from `git init` use so probably good enough.
      File.chmod(00755, HOOK_PATH)
      say('DCO auto-sign-off enabled', :green)
    end

    desc 'disable', 'Disable auto-sign-off for this repository'
    def disable
      assert_repo!
      unless our_hook?
        raise Thor::Error.new('commit-msg hook is external, not removing')
      end
      if File.exist?(HOOK_PATH)
        File.unlink(HOOK_PATH)
      end
      say('DCO auto-sign-off disabled', :green)
    end

    desc 'sign', 'Retroactively apply sign-off to the a branch'
    option :base, type: :string, banner: '<branch>', default: 'master', desc: 'Base branch (default: master)'
    option :behalf, aliases: 'b', type: :string, banner: '<url>'
    option :yes, aliases: 'y', type: :boolean
    def sign(branch=nil)
      # What two branches are we using?
      base_branch = options[:base]
      branch ||= current_branch
      if base_branch == branch
        # This should also catch people trying to sign-off on master.
        raise Thor::Error.new("Cannot use #{branch} for both the base and target branch")
      end

      # First check for a stored ref under refs/original/.
      begin
        repo.show("refs/original/refs/heads/#{branch}")
        # If this doesn't error, a backup ref is present.
        unless confirm?("An existing backup of branch #{branch} is present from a previous filter-branch. Do you want to remove this backup and continue? [yes/no]")
          raise Thor::Error.new('Backup ref present, not continuing')
        end
        # Clear the backup.
        File.unlink(".git/refs/original/refs/heads/#{branch}")
      rescue Git::GitExecuteError
        # This means there was no backup, keep going.
      end

      # Next examine all the commits we will be touching.
      commits = repo.log.between(base_branch, branch).to_a.select {|commit| !has_sign_off?(commit) }
      if commits.empty?
        raise Thor::Error.new("Branch #{branch} has no commits which require sign-off")
      end
      if !options[:behalf] && commits.any? {|commit| commit.author.email != repo_config['user.email'] }
        raise Thor::Error.new("Branch #{branch} contains commits not authored by you. Please use the --behalf flag when signing off for another contributor")
      end

      # Display the DCO text.
      say("#{DCO_TEXT}\n\n", :yellow) unless options[:behalf]

      # Display the list of commits.
      say("Going to sign-off the following commits:")
      commits.each do |commit|
        say("* #{format_commit(commit)}")
      end

      # Get confirmation.
      confirm_msg = if options[:behalf]
        "Do you, #{git_identity}, certify that these commits are contributed under the terms of the Developer Certificate of Origin as evidenced by #{options[:behalf]}? [yes/no]"
      else
        "Do you, #{git_identity}, certify that these commits are contributed under the terms of the Developer Certificate of Origin? [yes/no]"
      end
      unless confirm?(confirm_msg)
        raise Thor::Error.new('Not signing off on commits without approval')
      end

      # Stash if needed.
      did_stash = false
      status = repo.status
      unless status.changed.empty? && status.added.empty? && status.deleted.empty?
        say("Stashing uncommited changes before continuing")
        # repo.branch(repo.current_branch).stashes.save('dco-sign temp stash')
        repo.lib.send(:command, 'stash', ['save', 'dco sign temp stash'])
        did_stash = true
      end

      # Run the filter branch. Here be dragons. Yes, I'm calling a private method. I'm sorry.
      filter_cmd = [Thor::Util.ruby_command, File.expand_path('../../../bin/dco', __FILE__), 'process_commit_message', '--repo', repo.dir.path]
      if options[:behalf]
        filter_cmd << '--behalf'
        filter_cmd << options[:behalf]
      end
      begin
        output = repo.lib.send(:command, 'filter-branch', ['--msg-filter', Shellwords.join(filter_cmd), "#{base_branch}..#{branch}"])
        say(output)
       ensure
        if did_stash
          # If we had a stash, make sure to replay it.
          say("Unstashing previous changes")
          repo.branch(repo.current_branch).stashes.apply
          # For whatever reason, the git gem doesn't expose this.
          repo.lib.send(:command, 'stash', ['drop'])
        end
      end

      # Hopefully that worked.
      say("Sign-off complete", :green)
      say("Don't forget to use --force when pushing this branch to your git server (eg. git push --force origin #{branch})", :green) # TODO I could detect the actual remote for this branch, if any.
    end

    desc 'check', 'Check if a branch or repository has valid sign-off'
    option :all, type: :boolean, aliases: 'a', desc: 'Check commits, not just a single branch'
    option :base, type: :string, banner: '<branch>', default: 'master', desc: 'Base branch (default: master)'
    option :quiet, type: :boolean, aliases: 'q', desc: 'Quiet output'
    option :allow_author_mismatch, type: :boolean, desc: 'Allow author vs. sign-off mismatch'
    def check(branch=nil)
      branch ||= current_branch
      log = (options[:all] || branch == options[:base]) ? repo.log :  repo.log.between(options[:base], branch)
      bad_commits = []
      log.each do |commit|
        sign_off = has_sign_off?(commit)
        if !sign_off
          # No sign-off at all, tsk tsk.
          bad_commits << [commit, :no_sign_off]
        elsif !options[:allow_author_mismatch] && sign_off != "#{commit.author.name} <#{commit.author.email}>"
          # The signer-off and commit author don't match.
          bad_commits << [commit, :author_mismatch]
        end
      end

      if bad_commits.empty?
        # Yay!
        say("All commits are signed off", :green) unless options[:quiet]
      else
        # Something bad happened.
        unless options[:quiet]
          say("N: No Sign-off   M: Author mismatch", :red)
          bad_commits.each do |commit, reason|
            reason_string = {no_sign_off: 'N', author_mismatch: 'M'}[reason]
            say("#{reason_string} #{format_commit(commit)}", :red)
          end
        end
        exit 1
      end
    end

    private

    # Modified version of Thor's #yes? to understand -y and non-interactive usage.
    #
    # @api private
    # @param msg [String] Message to show
    # @return [Boolean]
    def confirm?(msg)
      return true if options[:yes]
      unless STDOUT.isatty
        say(msg)
        return false
      end
      yes?(msg)
    end

    # Check that we are in a git repo that we have write access to.
    #
    # @api private
    # @return [void]
    def assert_repo!
      begin
        # Check if the repo fails to load at all.
        repo
      rescue Exception
        raise Thor::Error.new("#{repo_path} does not appear to be a git repository")
      end
      unless repo.repo.writable?
        raise Thor::Error.new("Git repository at #{repo.repo.path} is read-only")
      end
    end

    # Create a Git repository object for the current repo.
    #
    # @api private
    # @return [Git::Base]
    def repo
      @repo ||= Git.open(repo_path)
    end

    # Return and cache the git config for this repo because we use it a lot.
    #
    # @api private
    # @return [Hash]
    def repo_config
      @repo_config ||= repo.config
    end

    # Get the current branch but raise an error if it looks like we're on a detched head.
    #
    # @api private
    # @return [String]
    def current_branch
      repo.current_branch.tap {|b| raise Thor::Error.new("No explicit branch passed and current head looks detached: #{b}") if b[0] == '(' }
    end

    # Check if we are in control of the commit-msg hook.
    #
    # @api private
    # @return [Boolean]
    def our_hook?
      !File.exist?(HOOK_PATH) || IO.read(HOOK_PATH).include?('INSTALLED BY DCO GEM')
    end

    # Find the git identity string for the current user.
    #
    # @api private
    # @return [String]
    def git_identity
      "#{repo_config['user.name']} <#{repo_config['user.email']}>"
    end

    # Make a one-line version of a commit for use in displays.
    #
    # @api private
    # @param commit [Git::Commit] Commit object to format
    # @return [String]
    def format_commit(commit)
      "#{commit.sha[0..6]} #{commit.author.name} <#{commit.author.email}> #{commit.message.split(/\n/).first}"
    end

    # Check if a commit or commit message is already signed off.
    #
    # @api private
    # @param commit_or_message [String, Git::Commit] Commit object or message string.
    # @return [String, nil]
    def has_sign_off?(commit_or_message)
      message = commit_or_message.is_a?(String) ? commit_or_message : commit_or_message.message
      if message =~ /^Signed-off-by: (.+)$/
        $1
      else
        nil
      end
    end
  end
end
