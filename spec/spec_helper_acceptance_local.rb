# rubocop:disable Style/AccessorMethodName

require 'support/acceptance/helpers'
require 'support/acceptance/shared_examples'
require 'support/acceptance/shared_contexts'

RSpec.configure do |config|
  include TargetHelpers

  config.before(:suite) do
    # Stop the puppet service on the master to avoid edge-case conflicting
    # Puppet runs (one triggered by service vs one we trigger)
    master.run_shell('puppet resource service puppet ensure=stopped')
  end
end

# TODO: This will cause some problems if we run the tests
# in parallel. For example, what happens if two targets
# try to modify site.pp at the same time?
def set_sitepp_content(manifest)
  content = <<-HERE
  node default {
    #{manifest}
  }
  HERE

  write_file(master, '/etc/puppetlabs/code/environments/production/manifests/site.pp', content)
end

def write_file(target, dest, content)
  # Litmus doesn't have a 'write_file' helper so we write our own
  # by taking advtange of create_manifest_file
  path = target.create_manifest_file(content)
  target.run_shell("mv #{path} #{dest}")
end

def trigger_puppet_run(target, acceptable_exit_codes: [0, 2])
  result = target.run_shell('puppet agent -t --detailed-exitcodes', expect_failures: true)
  unless acceptable_exit_codes.include?(result[:exit_code])
    raise "Puppet run failed\nstdout: #{result[:stdout]}\nstderr: #{result[:stderr]}"
  end
  result
end

def declare(type, title, params = {})
  params = params.map do |name, value|
    value = "'#{value}'" if value.is_a?(String)
    "  #{name} => #{value},"
  end

  <<-HERE
  #{type} { '#{title}':
  #{params.join("\n")}
  }
  HERE
end

def to_manifest(*declarations)
  declarations.join("\n")
end
