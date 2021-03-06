# Radius Server provider class

# Jonathan Tripathy et al., September 2015

# Copyright (c) 2014-2015 Cisco and/or its affiliates.

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

#     http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require File.join(File.dirname(__FILE__), 'node_util')

module Cisco
  # RadiusServer - node utility class for
  # Raidus Server configuration management
  class RadiusServer < NodeUtil
    attr_reader :name

    def initialize(name, instantiate=true)
      unless name[/^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$/]
        fail ArgumentError, 'Invalid value (Name is not an IP address)'
      end
      @name = name

      create if instantiate
    end

    def self.radiusservers
      hash = {}

      radiusservers_list = config_get('radius_server', 'hosts')
      return hash if radiusservers_list.nil?

      radiusservers_list.each do |id|
        hash[id] = RadiusServer.new(id, false)
      end

      hash
    end

    def create
      config_set('radius_server',
                 'hosts',
                 state: '',
                 ip:    @name)
    end

    def destroy
      config_set('radius_server',
                 'hosts',
                 state: 'no',
                 ip:    @name)
    end

    def ==(other)
      name == other.name
    end

    def auth_port
      val = config_get('radius_server', 'auth-port', @name)
      val = val[0].to_i unless val.nil?
      val
    end

    def default_auth_port
      val = config_get_default('radius_server', 'auth-port')
      val
    end

    def auth_port=(val)
      unless val.nil?
        fail ArgumentError, 'auth_port must be an Integer' \
          unless val.is_a?(Integer)
      end

      if val.nil? && !auth_port.nil?
        config_set('radius_server',
                   'auth-port',
                   state: 'no',
                   ip:    @name,
                   port:  auth_port)
      else
        config_set('radius_server',
                   'auth-port',
                   state: '',
                   ip:    @name,
                   port:  val)
      end
    end

    def acct_port
      val = config_get('radius_server', 'acct-port', @name)
      val = val[0].to_i unless val.nil?
      val
    end

    def default_acct_port
      val = config_get_default('radius_server', 'acct-port')
      val
    end

    def acct_port=(val)
      unless val.nil?
        fail ArgumentError, 'acct_port must be an Integer' \
          unless val.is_a?(Integer)
      end

      if val.nil? && !acct_port.nil?
        config_set('radius_server',
                   'acct-port',
                   state: 'no',
                   ip:    @name,
                   port:  acct_port)
      else
        config_set('radius_server',
                   'acct-port',
                   state: '',
                   ip:    @name,
                   port:  val)
      end
    end

    def timeout
      val = config_get('radius_server', 'timeout', @name)
      val = val[0].to_i unless val.nil?
      val
    end

    def default_timeout
      val = config_get_default('radius_server', 'timeout')
      val
    end

    def timeout=(val)
      unless val.nil?
        fail ArgumentError, 'timeout must be an Integer' \
          unless val.is_a?(Integer)
      end

      if val.nil? && !timeout.nil?
        config_set('radius_server',
                   'timeout',
                   state:   'no',
                   ip:      @name,
                   timeout: timeout)
      else
        config_set('radius_server',
                   'timeout',
                   state:   '',
                   ip:      @name,
                   timeout: val)
      end
    end

    def retransmit_count
      val = config_get('radius_server', 'retransmit', @name)
      val = val[0].to_i unless val.nil?
      val
    end

    def default_retransmit_count
      val = config_get_default('radius_server', 'retransmit')
      val
    end

    def retransmit_count=(val)
      unless val.nil?
        fail ArgumentError, 'retransmit_count must be an Integer' \
          unless val.is_a?(Integer)
      end

      if val.nil? && !retransmit_count.nil?
        config_set('radius_server',
                   'retransmit',
                   state: 'no',
                   ip:    @name,
                   count: retransmit_count)
      else
        config_set('radius_server',
                   'retransmit',
                   state: '',
                   ip:    @name,
                   count: val)
      end
    end

    def accounting
      val = config_get('radius_server', 'accounting', @name)
      if val.nil?
        false
      else
        val[0].eql?('accounting') ? true : false
      end
    end

    def default_accounting
      val = config_get_default('radius_server', 'accounting')
      val
    end

    def accounting=(val)
      if !val
        config_set('radius_server',
                   'accounting',
                   state: 'no',
                   ip:    @name)
      else
        config_set('radius_server',
                   'accounting',
                   state: '',
                   ip:    @name)
      end
    end

    def authentication
      val = config_get('radius_server', 'authentication', @name)
      if val.nil?
        false
      else
        val[0].eql?('authentication') ? true : false
      end
    end

    def default_authentication
      val = config_get_default('radius_server', 'authentication')
      val
    end

    def authentication=(val)
      if !val
        config_set('radius_server',
                   'authentication',
                   state: 'no',
                   ip:    @name)
      else
        config_set('radius_server',
                   'authentication',
                   state: '',
                   ip:    @name)
      end
    end

    def key_format
      val = config_get('radius_server', 'key_format', @name)
      val = val[0].to_i unless val.nil?
      val
    end

    def key
      val = config_get('radius_server', 'key', @name)
      val = val[0] unless val.nil?
      val
    end

    def key_set(value, format)
      unless value.nil?
        fail ArgumentError, 'value must be a String' \
          unless value.is_a?(String)
      end

      unless format.nil?
        fail ArgumentError, 'format must be an Integer' \
          unless format.is_a?(Integer)
      end

      if value.nil? && !key.nil?
        config_set('radius_server',
                   'key',
                   state: 'no',
                   ip:    @name,
                   key:   "#{key_format} #{key}")
      elsif !format.nil?
        config_set('radius_server',
                   'key',
                   state: '',
                   ip:    @name,
                   key:   "#{format} #{value}")
      else
        config_set('radius_server',
                   'key',
                   state: '',
                   ip:    @name,
                   key:   "#{value}")
      end
    end
  end # class
end # module
