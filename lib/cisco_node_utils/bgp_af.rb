# -*- coding: utf-8 -*-
# August 2015, Richard Wellum
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

require File.join(File.dirname(__FILE__), 'cisco_cmn_utils')
require File.join(File.dirname(__FILE__), 'node_util')
require File.join(File.dirname(__FILE__), 'bgp')

module Cisco
  # RouterBgpAF - node utility class for BGP address-family config management
  class RouterBgpAF < NodeUtil
    def initialize(asn, vrf, af, instantiate=true)
      fail ArgumentError if vrf.to_s.empty? || af.to_s.empty?
      err_msg = '"af" argument must be an array of two string values containing ' \
                'an afi + safi tuple'
      fail ArgumentError, err_msg unless af.is_a?(Array) || af.length == 2
      @asn = RouterBgp.process_asnum(asn)
      @vrf = vrf
      @afi, @safi = af
      set_args_keys_default
      create if instantiate
    end

    def self.afs
      af_hash = {}
      RouterBgp.routers.each do |asn, vrfs|
        af_hash[asn] = {}
        vrfs.keys.each do |vrf_name|
          get_args = { asnum: asn }
          get_args[:vrf] = vrf_name unless (vrf_name == 'default')
          # Call yaml and search for address-family statements
          af_list = config_get('bgp_af', 'all_afs', get_args)

          next if af_list.nil?

          af_hash[asn][vrf_name] = {}
          af_list.each do |af|
            af_hash[asn][vrf_name][af] = RouterBgpAF.new(asn, vrf_name, af, false)
          end
        end
      end
      af_hash
    end

    def create
      set_args_keys(state: '')
      config_set('bgp', 'address_family', @set_args)
    end

    def destroy
      set_args_keys(state: 'no')
      config_set('bgp', 'address_family', @set_args)
    end

    #
    # Helper methods to delete @set_args hash keys
    #
    def set_args_keys_default
      keys = { asnum: @asn, afi: @afi, safi: @safi }
      keys[:vrf] = @vrf unless @vrf == 'default'
      @get_args = @set_args = keys
    end

    def set_args_keys(hash={}) # rubocop:disable Style/AccessorMethodName
      set_args_keys_default
      @set_args = @get_args.merge!(hash) unless hash.empty?
    end

    ########################################################
    #                      PROPERTIES                      #
    ########################################################

    #
    # Client to client
    #
    def client_to_client
      state = config_get('bgp_af', 'client_to_client', @get_args)
      state ? true : false
    end

    def client_to_client=(state)
      state = (state ? '' : 'no')
      set_args_keys(state: state)
      config_set('bgp_af', 'client_to_client', @set_args)
    end

    def default_client_to_client
      config_get_default('bgp_af', 'client_to_client')
    end

    #
    # Default Information (Getter/Setter/Default)
    #
    def default_information_originate
      state = config_get('bgp_af', 'default_information', @get_args)
      state ? true : false
    end

    def default_information_originate=(state)
      state = (state ? '' : 'no')
      set_args_keys(state: state)
      config_set('bgp_af', 'default_information', @set_args)
    end

    def default_default_information_originate
      config_get_default('bgp_af', 'default_information')
    end

    #
    # Next Hop route map (Getter/Setter/Default)
    #
    def next_hop_route_map
      route_map = config_get('bgp_af', 'next_hop_route_map', @get_args)
      return '' if route_map.nil?
      route_map.shift.strip
    end

    def next_hop_route_map=(route_map)
      route_map.strip!
      if route_map.empty?
        state = 'no'
        route_map = next_hop_route_map
      end
      set_args_keys(state: state, route_map: route_map)
      config_set('bgp_af', 'next_hop_route_map', @set_args)
    end

    def default_next_hop_route_map
      config_get_default('bgp_af', 'next_hop_route_map')
    end

    #
    # Network (Getter/Setter/Default)
    #
    # Get list of all networks configured on the device indexed
    # under the asn/vrf/af specified in @get_args
    def networks
      nets = config_get('bgp_af', 'network', @get_args)
      if nets.nil?
        default_networks
      else
        # Removes nested nil Array elements.
        nets.map { |e| e.is_a?(Array) ? e.compact : e }.compact
      end
    end

    # Add or remove a single network on the device under
    # the asn/vrf/af specified in @get_args
    def network_set(network, route_map=nil, remove=false)
      # Process ip/prefix format
      network = Utils.process_network_mask(network)
      state = remove ? 'no' : ''
      route_map = "route-map #{route_map}" unless route_map.nil?
      set_args_keys(state: state, network: network, route_map: route_map)
      config_set('bgp_af', 'network', @set_args)
    end

    # Wrapper for removing networks
    def network_remove(network, route_map=nil)
      network_set(network, route_map, true)
    end

    # Create list of networks to add and/or remove from the
    # device under asn/vrf/af
    def networks_delta(should_list)
      # TODO: Make sure to validate array of arrays containing
      # [network, routemap] tuples in puppet/chef
      # Munge:
      # should_list[0].class should be an array
      # should_list[1].class should be a string

      # Compact should_list that contains nested arrays elements
      # to remove any nil items first.
      # Rebuild should_list without any nil items and process
      # network mask.
      should_list_new = []
      should_list.each do |network, routemap|
        network = Utils.process_network_mask(network)
        if routemap.nil?
          should_list_new << [network]
        else
          should_list_new << [network, routemap]
        end
      end
      delta = { add:    should_list_new - networks,
                remove: networks - should_list_new }
      # If we are updating routemaps for networks that
      # already exist delete these from the :remove list
      #
      # TODO: Investigate better ways to do this given it's
      # O(N*M) - O(<size of add_list> * <size of remove_list>)
      delta[:add].each do |net, _|
        delta[:remove].delete(scrub_remove_list(net, delta[:remove]))
      end
      delta
    end

    def scrub_remove_list(network, remove_list)
      remove_item = []
      remove_list.each do |net, rtmap|
        remove_item = [net, rtmap] if net.to_s == network.to_s
        return remove_item if remove_item.size > 0
      end
      remove_item
    end

    def networks=(delta_hash)
      # Nothing to do if both add and remove lists are empty
      return if delta_hash[:add].size == 0 &&
                delta_hash[:remove].size == 0
      # Process add list
      if delta_hash[:add].size > 0
        CiscoLogger.debug('Adding the following networks to ' \
          "asn: #{@asn} vrf: #{@vrf} af: #{@afi} #{@safi}:\n" \
          "#{delta_hash[:add]}")
        delta_hash[:add].each do |network, rtmap|
          network_set(network, rtmap)
        end
      end
      # Process remove list
      if delta_hash[:remove].size > 0 # rubocop:disable Style/GuardClause
        CiscoLogger.debug('Removing the following networks from ' \
          "asn: #{@asn} vrf: #{@vrf} af: #{@afi} #{@safi}:\n" \
          "#{delta_hash[:remove]}")
        delta_hash[:remove].each do |network, rtmap|
          network_remove(network, rtmap)
        end
      end
    end

    def default_networks
      config_get_default('bgp_af', 'network')
    end
  end
end