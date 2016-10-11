#
# Copyright 2014-2016, Chef Software Inc.
# Copyright 2016, Noah Kantrowitz
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
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
  module Command
    if defined?(ChefDK::Command::Base)
      Base = ChefDK::Command::Base
    else
      class Base
        include Mixlib::CLI

        option :help,
          :short        => "-h",
          :long         => "--help",
          :description  => "Show this message",
          :boolean      => true

        option :version,
          :short        => "-v",
          :long         => "--version",
          :description  => "Show version",
          :boolean      => true

        #
        # optparser overwrites -h / --help options with its own.
        # In order to control this behavior, make sure the default options are
        # handled here.
        #
        def run_with_default_options(params = [ ])
          if needs_help?(params)
            msg(opt_parser)
            0
          elsif needs_version?(params)
            msg("DCO gem version #{Dco::VERSION}")
            0
          else
            run(params)
          end
        rescue OptionParser::InvalidOption, OptionParser::MissingArgument => e
          err("ERROR: #{e.message}\n")
          msg(opt_parser)
          1
        end

        def needs_help?(params)
          params.include?("-h") || params.include?("--help")
        end

        def needs_version?(params)
          params.include?("-v") || params.include?("--version")
        end

      end
    end
  end
end
