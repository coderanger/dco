#
# Copyright 2014-2016, Chef Software Inc.
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

require 'mixlib/cli'

require 'dco/version'


module Dco
  class CLI
    include Mixlib::CLI

    banner(<<-BANNER)
Usage:
    dco -h/--help
    dco -v/--version
    dco command [arguments...] [options...]
BANNER

    option :version,
      :short        => "-v",
      :long         => "--version",
      :description  => "Show dco version",
      :boolean      => true

    option :help,
      :short        => "-h",
      :long         => "--help",
      :description  => "Show this message",
      :boolean      => true

    attr_reader :argv

    def initialize(argv)
      @argv = argv
      # mixlib-cli #initialize doesn't allow arguments.
      super()
    end

    def run
      subcommand_name, *subcommand_params = argv

      # Check for global options or a subcommand.
      case subcommand_name
      when nil, /^-/
        handle_options
      when 'enable', 'disable', 'apply'
        require "dco/command/#{subcommand_name}"
        cmd_class = Dco::Command.const_get(subcommand_name.capitalize)
        subcommand = cmd_class.new
        exit_code = subcommand.run_with_default_options(subcommand_params)
        exit normalized_exit_code(exit_code)
      else
        err "Unknown command `#{subcommand_name}'."
        show_help
        exit 1
      end
    rescue OptionParser::InvalidOption => e
      err(e.message)
      show_help
      exit 1
    end

    # If no subcommand is given, then this class is handling the CLI request.
    def handle_options
      parse_options(argv)
      if config[:version]
        show_version
      else
        show_help
      end
      exit 0
    end

    def show_version
      msg("DCO gem version: #{DCO::VERSION}")
    end

    def show_help
      msg(banner)
      # Display other stuff later.
    end

    private

    def normalized_exit_code(maybe_integer)
      if maybe_integer.is_a?(Integer) && (0..255).include?(maybe_integer)
        maybe_integer
      else
        0
      end
    end

  end
end
