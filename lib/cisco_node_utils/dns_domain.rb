#
# NXAPI implementation of DnsDomain class
#
# September 2015, Hunter Haugen
#
# Copyright (c) 2015 Cisco and/or its affiliates.
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
# "group" is a standard SNMP term but in NXOS "role" is used to serve the
# purpose of group; thus this provider utility does not create snmp groups
# and is limited to reporting group (role) existence only.

require_relative 'node_util'

module Cisco
  # DnsDomain - node utility class for DNS search domain config management
  class DnsDomain < NodeUtil
    attr_reader :name, :vrf

    def initialize(name, vrf=nil, instantiate=true)
      unless name.is_a? String
        fail TypeError, "Expected a string, got a #{name.class.inspect}"
      end
      @name = name
      @vrf = vrf
      create if instantiate
    end

    def self.dnsdomains(vrf=nil)
      if vrf.nil?
        domains = config_get('dnsclient', 'domain_list')
      else
        domains = config_get('dnsclient', 'domain_list_vrf', vrf: vrf)
      end
      return {} if domains.nil?

      hash = {}
      domains.each do |name|
        hash[name] = DnsDomain.new(name, vrf, false)
      end
      hash
    end

    def ==(other)
      (name == other.name) && (vrf == other.vrf)
    end

    def create
      if @vrf.nil?
        config_set('dnsclient', 'domain_list',
                   state: '', name: @name)
      else
        config_set('dnsclient', 'domain_list_vrf',
                   state: '', name: @name, vrf: @vrf)
      end
    end

    def destroy
      if @vrf.nil?
        config_set('dnsclient', 'domain_list',
                   state: 'no', name: @name)
      else
        config_set('dnsclient', 'domain_list_vrf',
                   state: 'no', name: @name, vrf: @vrf)
      end
    end
  end
end
