require 'puppet/util/network_device/dell_iom/model'
require 'puppet/util/network_device/dell_iom/model/ioa_mode'

module Puppet::Util::NetworkDevice::Dell_iom::Model::Ioa_mode::Base
  def self.ifprop(base, param, base_command = param, &block)

    base.register_scoped param, /((.*))/ do
      cmd 'show system stack-unit 0 iom-mode'
      Puppet.debug("Name: #{base.name}")
      match /.*/
      add do |transport, value|
        Puppet.debug(" command #{base_command} value  #{value}" )
        transport.command("#{base_command} #{value}")
      end
      remove do |transport, old_value|
        Puppet.debug(" No  command #{base_command} value  #{value}" )
        transport.command("no #{base_command} #{old_value}")
      end
      evaluate(&block) if block
    end
  end

  def self.register(base)
    Puppet.debug("base: #{base.name}")
    txt = ''
    ifprop(base, :ensure) do
      match do |txt|
        if txt.match(/base.name/)
          :present
        else
          :absent
        end
      end
      default :absent

      add { |*_| }
      remove { |*_| }
    end

    ifprop(base, :iom_mode) do
      Puppet.debug("Base name: #{base.name}")

      desired_iom_mode = 'programmable-mux' if base.name.downcase.match(/pmux|programmable*/)
      desired_iom_mode = 'standalone' if base.name.downcase.match(/smux|stand*/)
      desired_iom_mode = 'vlt' if base.name.downcase.match(/vlt*/)
      Puppet.debug("desired iom mode: #{desired_iom_mode}")
      match do |txt|
        Puppet.debug("TXT for matching: #{txt}")
        :present
      end
      default :absent

      if base.facts['iom_mode'] != desired_iom_mode
        # For VLT, change the switch to ethernet mode for FN 2210S IOA
        if desired_iom_mode == 'vlt' and base.facts['product_name'].match(/2210S/)
          transport.command('enable')
          transport.command('configure terminal', :prompt => /\(conf\)#\z/n)
          transport.command('stack-unit 0 port-group 0 portmode ethernet',:prompt => /confirm.*/ )
          transport.command('yes')
          transport.command('end')

          # Save the configuration and reload switch
          transport.command('enable')
          transport.command('write memory')
          transport.command('reload', :prompt => /confirm.*/i)
          transport.command('yes')
          # Close connection and call connect method to restore the connection
          transport.close
          # Sleeping for a minute
          (1..5).each do |retry_count|
            sleep(60)
            begin
              transport.connect
              break
            rescue Exception => e
              Puppet.debug("Failed to connect, retry counter #{retry_count}")
            end
          end
        end

        transport.command('enable')
        transport.command('configure terminal', :prompt => /\(conf\)#\z/n)
        transport.command("stack-unit 0 iom-mode #{desired_iom_mode}")
        transport.command('end')
        # Save the configuration and reload switch
        transport.command('write memory')
        transport.command('reload', :prompt => /confirm.*/)
        transport.command('yes')
        base.facts['iom_mode'] = desired_iom_mode

        # Close connection and call connect method to restore the connection
        transport.close
        # Sleeping for a minute
        (1..5).each do |retry_count|
          sleep(60)
          begin
            transport.connect
            # Sleeping for additional minute to allow switch to come to normal state
            Puppet.debug('Sleeping for additional minute to allow switch to come to normal state')
            sleep(60)
            break
          rescue Exception => e
            Puppet.debug("Failed to connect, retry counter #{retry_count}")
          end
        end
      end

      add { |*_| }
      remove { |*_| }
    end
  end
end
