#
# NXAPI implementation of RouterBgp class
#
# June 2015, Michael G Wiebe
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

require File.join(File.dirname(__FILE__), 'node')

module Cisco
class RouterBgp
  attr_reader :asnum, :vrf

  @@node = Cisco::Node.instance

  def initialize(asnum, vrf='default', instantiate=true)
    raise ArgumentError unless vrf.is_a? String
    raise ArgumentError unless vrf.length > 0
    @asnum = process_asnum(asnum)
    @vrf = vrf
    @get_args = @set_args = (@vrf == 'default') ?
      { :asnum => @asnum } : { :asnum => @asnum, :vrf => @vrf }

    create if instantiate
  end

  def process_asnum(asnum)
    err_msg = "BGP asnum must be either a 'String' or an" +
              " 'Integer' object"
    raise ArgumentError, err_msg unless asnum.is_a? Integer or
                                        asnum.is_a? String
    if asnum.is_a? String
      # Match ASDOT '1.5' or ASPLAIN '55' strings
      raise ArgumentError unless /\d+.?\d+?/.match(asnum)
      asnum = RouterBgp.dot_to_big(asnum) if /\d+.\d+/.match(asnum)
    end
    asnum.to_i
  end

  # Create a hash of all router bgp default and non-default
  # vrf instances
  def RouterBgp.routers
    bgp_ids = @@node.config_get("bgp", "router")
    return {} if bgp_ids.nil?

    hash_final = {}
    # TODO: Remove loop if only single ASN supported by RFC?
    bgp_ids.each do |asnum|
      asnum = asnum.to_i unless /\d+.\d+/.match(asnum)
      hash_tmp = { asnum =>
        { 'default' => RouterBgp.new(asnum, 'default', false) } }
      vrf_ids = @@node.config_get("bgp", "vrf", { :asnum => asnum })
      unless vrf_ids.nil?
        vrf_ids.each do |vrf|
          hash_tmp[asnum][vrf] = RouterBgp.new(asnum, vrf, false)
        end
      end
      hash_final.merge!(hash_tmp)
    end
    return hash_final
  rescue Cisco::CliError => e
    # cmd will syntax reject when feature is not enabled
    raise unless e.clierror =~ /Syntax error/
    return {}
  end

  def RouterBgp.enabled
    feat =  @@node.config_get("bgp", "feature")
    return (!feat.nil? and !feat.empty?)
  rescue Cisco::CliError => e
    # cmd will syntax reject when feature is not enabled
    raise unless e.clierror =~ /Syntax error/
    return false
  end

  def RouterBgp.enable(state="")
    @@node.config_set("bgp", "feature", { :state => state })
  end

  # Convert BGP ASN ASDOT+ to ASPLAIN
  def RouterBgp.dot_to_big(dot_str)
    raise ArgumentError unless dot_str.is_a? String
    return dot_str unless /\d+\.\d+/.match(dot_str)
    mask = 0b1111111111111111
    high = dot_str.to_i
    low = 0
    low_match = dot_str.match(/\.(\d+)/)
    low = low_match[1].to_i if low_match
    high_bits = (mask & high) << 16
    low_bits = mask & low
    high_bits + low_bits
  end

  def router_bgp(asnum, vrf, state="")
    # Only one bgp autonomous system number is allowed
    # Raise an error if one is already configured that
    # differs from the one being created.
    configured = @@node.config_get("bgp", "router")
    if !configured.nil? && configured.first.to_s != asnum.to_s
      raise = %(
        Changing the BGP Autonomous System Number is not allowed.
        Current BGP asn: #{configured.first}
        Attempted change to asn: #{asnum}
            )
    end
    @set_args[:state] = state
    vrf == 'default' ?
      @@node.config_set("bgp", "router", @set_args) :
      @@node.config_set("bgp", "vrf", @set_args)
    set_args_keys_default()
  end

  def enable_create_router_bgp(asnum, vrf)
    RouterBgp.enable
    router_bgp(asnum, vrf)
  end

  # Create one router bgp instance
  def create
    if RouterBgp.enabled
      router_bgp(@asnum, @vrf)
    else
      enable_create_router_bgp(@asnum, @vrf)
    end
  end

  # Destroy router bgp instance
  def destroy
    vrf_ids = @@node.config_get("bgp", "vrf", { :asnum => @asnum })
    vrf_ids = ['default'] if vrf_ids.nil?
    if vrf_ids.size == 1 or @vrf == 'default'
      RouterBgp.enable("no")
    else
      router_bgp(asnum, @vrf, "no")
    end
  rescue Cisco::CliError => e
    # cmd will syntax reject when feature is not enabled
    raise unless e.clierror =~ /Syntax error/
  end

  # Helper method to delete @set_args hash keys
  def set_args_keys_default
    @vrf == 'default' ?
      @set_args = { :asnum => @asnum } :
      @set_args = { :asnum => @asnum, :vrf => @vrf }
  end

  # Attributes:

  # WARNING: BGP defect CSCuv52710 impacts these tests in the following manner.
  #
  # If an attempt is made to remove certain features when they not configured
  # using nxapi, a code: 400 clierror is generated.  This causes problems
  # when puppet attempts to create a new resource and set the parameter to
  # it's default value.  To work around this we will call the getter method
  # and only set the value if it's different then the current value.
  def workaround_CSCuv52710(test_value, current_value)
    test_value == current_value
  end

  # Bestpath Getters
  def bestpath_always_compare_med
    match = @@node.config_get("bgp", "bestpath_always_compare_med", @get_args)
    match.nil? ? default_bestpath_always_compare_med : true
  end

  def bestpath_aspath_multipath_relax
    match = @@node.config_get("bgp", "bestpath_aspath_multipath_relax", @get_args)
    match.nil? ? default_bestpath_aspath_multipath_relax : true
  end

  def bestpath_compare_routerid
    match = @@node.config_get("bgp", "bestpath_compare_routerid", @get_args)
    match.nil? ? default_bestpath_compare_routerid : true
  end

  def bestpath_cost_community_ignore
    match = @@node.config_get("bgp", "bestpath_cost_community_ignore", @get_args)
    match.nil? ? default_bestpath_cost_community_ignore : true
  end

  def bestpath_med_confed
    match = @@node.config_get("bgp", "bestpath_med_confed", @get_args)
    match.nil? ? default_bestpath_med_confed : true
  end

  def bestpath_med_non_deterministic
    match = @@node.config_get("bgp", "bestpath_med_non_deterministic", @get_args)
    match.nil? ? default_bestpath_med_non_deterministic : true
  end

  # Bestpath Setters
  def bestpath_always_compare_med=(enable)
    return if workaround_CSCuv52710(enable, bestpath_always_compare_med)
    @set_args[:state] = (enable ? "" : "no")
    @@node.config_set("bgp", "bestpath_always_compare_med", @set_args)
    set_args_keys_default()
  end

  def bestpath_aspath_multipath_relax=(enable)
    return if workaround_CSCuv52710(enable, bestpath_aspath_multipath_relax)
    @set_args[:state] = (enable ? "" : "no")
    @@node.config_set("bgp", "bestpath_aspath_multipath_relax", @set_args)
    set_args_keys_default()
  end

  def bestpath_compare_routerid=(enable)
    return if workaround_CSCuv52710(enable, bestpath_compare_routerid)
    @set_args[:state] = (enable ? "" : "no")
    @@node.config_set("bgp", "bestpath_compare_routerid", @set_args)
    set_args_keys_default()
  end

  def bestpath_cost_community_ignore=(enable)
    return if workaround_CSCuv52710(enable, bestpath_cost_community_ignore)
    @set_args[:state] = (enable ? "" : "no")
    @@node.config_set("bgp", "bestpath_cost_community_ignore", @set_args)
    set_args_keys_default()
  end

  def bestpath_med_confed=(enable)
    return if workaround_CSCuv52710(enable, bestpath_med_confed)
    @set_args[:state] = (enable ? "" : "no")
    @@node.config_set("bgp", "bestpath_med_confed", @set_args)
    set_args_keys_default()
  end

  def bestpath_med_non_deterministic=(enable)
    return if workaround_CSCuv52710(enable, bestpath_med_non_deterministic)
    @set_args[:state] = (enable ? "" : "no")
    @@node.config_set("bgp", "bestpath_med_non_deterministic", @set_args)
    set_args_keys_default()
  end

  # Bestpath Defaults
  def default_bestpath_always_compare_med
    @@node.config_get_default("bgp", "bestpath_always_compare_med")
  end

  def default_bestpath_aspath_multipath_relax
    @@node.config_get_default("bgp", "bestpath_aspath_multipath_relax")
  end

  def default_bestpath_compare_routerid
    @@node.config_get_default("bgp", "bestpath_compare_routerid")
  end

  def default_bestpath_cost_community_ignore
    @@node.config_get_default("bgp", "bestpath_cost_community_ignore")
  end

  def default_bestpath_med_confed
    @@node.config_get_default("bgp", "bestpath_med_confed")
  end

  def default_bestpath_med_non_deterministic
    @@node.config_get_default("bgp", "bestpath_med_non_deterministic")
  end

  # Cluster Id (Getter/Setter/Default)
  def cluster_id
    match = @@node.config_get("bgp", "cluster_id", @get_args)
    match.nil? ? default_cluster_id : match.first
  end

  def cluster_id=(id)
    # In order to remove a bgp cluster_id you cannot simply issue
    # 'no bgp cluster-id'.  IMO this should be possible because you
    # can only configure a single bgp cluster-id.
    #
    # HACK: specify a dummy id when removing the feature.
    # CSCuu76807
    return if workaround_CSCuv52710(id, cluster_id)
    dummy_id = 1
    id == default_cluster_id ?
      (@set_args[:state], @set_args[:id] = "no", dummy_id) :
      (@set_args[:state], @set_args[:id] = "", id)
    @@node.config_set("bgp", "cluster_id", @set_args)
    set_args_keys_default()
  end

  def default_cluster_id
    @@node.config_get_default("bgp", "cluster_id")
  end

  # Confederation Id (Getter/Setter/Default)
  def confederation_id
    match = @@node.config_get("bgp", "confederation_id", @get_args)
    match.nil? ? default_confederation_id : match.first
  end

  def confederation_id=(id)
    # In order to remove a bgp confed id you cannot simply issue
    # 'no bgp confederation id'.  IMO this should be possible
    # because you can only configure a single bgp confed id.
    #
    # HACK: specify a dummy id when removing the feature.
    # CSCuu76807
    return if workaround_CSCuv52710(id, confederation_id)
    dummy_id = 1
    id == default_confederation_id ?
      (@set_args[:state], @set_args[:id] = "no", dummy_id) :
      (@set_args[:state], @set_args[:id] = "", id)
    @@node.config_set("bgp", "confederation_id", @set_args)
    set_args_keys_default()
  end

  def default_confederation_id
    @@node.config_get_default("bgp", "confederation_id")
  end

  # Confederation Peers (Getter/Setter/Default)
  def confederation_peers
    match = @@node.config_get("bgp", "confederation_peers", @get_args)
    match.nil? ? default_confederation_peers : match.first
  end

  def confederation_peers_set(peers)
    return if workaround_CSCuv52710(peers, confederation_peers)
    # The confederation peers command is additive so we first need to
    # remove any existing peers.
    if not confederation_peers.empty?
      @set_args[:state], @set_args[:peer_list] = 'no', confederation_peers
      @@node.config_set("bgp", "confederation_peers", @set_args)
    end
    unless peers == default_confederation_peers
      @set_args[:state], @set_args[:peer_list] = '', peers
      @@node.config_set("bgp", "confederation_peers", @set_args)
    end
    set_args_keys_default()
  end

  def default_confederation_peers
    @@node.config_get_default("bgp", "confederation_peers")
  end

  # Graceful Restart Getters
  def graceful_restart
    match = @@node.config_get("bgp", "graceful_restart", @get_args)
    match.nil? ? false : default_graceful_restart
  end

  def graceful_restart_timers_restart
    match = @@node.config_get("bgp", "graceful_restart_timers_restart", @get_args)
    match.nil? ? default_graceful_restart_timers_restart : match.first.to_i
  end

  def graceful_restart_timers_stalepath_time
    match = @@node.config_get("bgp", "graceful_restart_timers_stalepath_time", @get_args)
    match.nil? ? default_graceful_restart_timers_stalepath_time : match.first.to_i
  end

  def graceful_restart_helper
    match = @@node.config_get("bgp", "graceful_restart_helper", @get_args)
    match.nil? ? default_graceful_restart_helper : true
  end

  # Graceful Restart Setters
  def graceful_restart=(enable)
    return if workaround_CSCuv52710(enable, graceful_restart)
    @set_args[:state] = (enable ? "" : "no")
    @@node.config_set("bgp", "graceful_restart", @set_args)
    set_args_keys_default()
  end

  def graceful_restart_timers_restart=(seconds)
    return if workaround_CSCuv52710(seconds, graceful_restart_timers_restart)
    seconds == default_graceful_restart_timers_restart ?
      (@set_args[:state], @set_args[:seconds] = "no", "") :
      (@set_args[:state], @set_args[:seconds] = "", seconds)
    @@node.config_set("bgp", "graceful_restart_timers_restart", @set_args)
    set_args_keys_default()
  end

  def graceful_restart_timers_stalepath_time=(seconds)
    return if workaround_CSCuv52710(seconds, graceful_restart_timers_stalepath_time)
    seconds == default_graceful_restart_timers_stalepath_time ?
      (@set_args[:state], @set_args[:seconds] = "no", "") :
      (@set_args[:state], @set_args[:seconds] = "", seconds)
    @@node.config_set("bgp", "graceful_restart_timers_stalepath_time", @set_args)
    set_args_keys_default()
  end

  def graceful_restart_helper=(enable)
    return if workaround_CSCuv52710(enable, graceful_restart_helper)
    @set_args[:state] = (enable ? "" : "no")
    @@node.config_set("bgp", "graceful_restart_helper", @set_args)
    set_args_keys_default()
  end

  # Graceful Restart Defaults
  def default_graceful_restart
    @@node.config_get_default("bgp", "graceful_restart")
  end

  def default_graceful_restart_timers_restart
    @@node.config_get_default("bgp", "graceful_restart_timers_restart")
  end

  def default_graceful_restart_timers_stalepath_time
    @@node.config_get_default("bgp", "graceful_restart_timers_stalepath_time")
  end

  def default_graceful_restart_helper
    @@node.config_get_default("bgp", "graceful_restart_helper")
  end

  # Log Neighbor Changes (Getter/Setter/Default)
  def log_neighbor_changes
    match = @@node.config_get("bgp", "log_neighbor_changes", @get_args)
    match.nil? ? default_log_neighbor_changes : true
  end

  def log_neighbor_changes=(enable)
    return if workaround_CSCuv52710(enable, log_neighbor_changes)
    @set_args[:state] = (enable ? "" : "no")
    @@node.config_set("bgp", "log_neighbor_changes", @set_args)
    set_args_keys_default()
  end

  def default_log_neighbor_changes
    @@node.config_get_default("bgp", "log_neighbor_changes")
  end

  # Neighbor fib down accelerate (Getter/Setter/Default)
  def neighbor_fib_down_accelerate
    match = @@node.config_get("bgp", "neighbor_fib_down_accelerate", @get_args)
    match.nil? ? default_neighbor_fib_down_accelerate : true
  end

  def neighbor_fib_down_accelerate=(enable)
    return if workaround_CSCuv52710(enable, neighbor_fib_down_accelerate)
    @set_args[:state] = (enable ? "" : "no")
    @@node.config_set("bgp", "neighbor_fib_down_accelerate", @set_args)
    set_args_keys_default()
  end

  def default_neighbor_fib_down_accelerate
    @@node.config_get_default("bgp", "neighbor_fib_down_accelerate")
  end

  # Reconnect Interval (Getter/Setter/Default)
  def reconnect_interval
    match = @@node.config_get("bgp", "reconnect_interval", @get_args)
    match.nil? ? default_reconnect_interval : match.first.to_i
  end

  def reconnect_interval=(seconds)
    return if workaround_CSCuv52710(seconds, reconnect_interval)
    seconds == default_reconnect_interval ?
      (@set_args[:state], @set_args[:seconds] = "no", "") :
      (@set_args[:state], @set_args[:seconds] = "", seconds)
    @@node.config_set("bgp", "reconnect_interval", @set_args)
    set_args_keys_default()
  end

  def default_reconnect_interval
    @@node.config_get_default("bgp", "reconnect_interval")
  end

  # Router ID (Getter/Setter/Default)
  def router_id
    match = @@node.config_get("bgp", "router_id", @get_args)
    match.nil? ? default_router_id : match.first
  end

  def router_id=(id)
    # In order to remove a bgp router-id you cannot simply issue
    # 'no bgp router-id'.  IMO this should be possible because you can only
    # configure a single bgp router-id.  I filed CSCuu76807 to track this
    # issue but it was closed.  Dummy-id specified to work around this.
    return if workaround_CSCuv52710(id, router_id)
    dummy_id = "1.2.3.4"
    id == default_router_id ?
      (@set_args[:state], @set_args[:id] = "no", dummy_id) :
      (@set_args[:state], @set_args[:id] = "", id)
    @@node.config_set("bgp", "router_id", @set_args)
    set_args_keys_default()
  end

  def default_router_id
    @@node.config_get_default("bgp", "router_id")
  end

  # Shutdown (Getter/Setter/Default)
  def shutdown
    match = @@node.config_get("bgp", "shutdown", @asnum)
    match.nil? ? default_shutdown : true
  end

  def shutdown=(enable)
    @set_args[:state] = (enable ? "" : "no")
    @@node.config_set("bgp", "shutdown", @set_args)
    set_args_keys_default()
  end

  def default_shutdown
    @@node.config_get_default("bgp", "shutdown")
  end

  # Supress Fib Pending (Getter/Setter/Default)
  def suppress_fib_pending
    match = @@node.config_get("bgp", "suppress_fib_pending", @get_args)
    match.nil? ? default_suppress_fib_pending : true
  end

  def suppress_fib_pending=(enable)
    return if workaround_CSCuv52710(enable, suppress_fib_pending)
      enable == true ? @set_args[:state] = "" : @set_args[:state] = "no"
      @@node.config_set("bgp", "suppress_fib_pending", @set_args)
      set_args_keys_default()
  end

  def default_suppress_fib_pending
    @@node.config_get_default("bgp", "suppress_fib_pending")
  end

  # BGP Timers Getters
  def timer_bgp_keepalive_hold
    match = @@node.config_get("bgp", "timer_bgp_keepalive_hold", @get_args)
    match.nil? ? default_timer_bgp_keepalive_hold : match.first
  end

  def timer_bgp_keepalive
    keepalive, hold = timer_bgp_keepalive_hold
    return default_timer_bgp_keepalive if keepalive.nil?
    keepalive.to_i
  end

  def timer_bgp_holdtime
    keepalive, hold = timer_bgp_keepalive_hold
    return default_timer_bgp_holdtime if hold.nil?
    hold.to_i
  end

  def timer_bestpath_limit
    match = @@node.config_get("bgp", "timer_bestpath_limit", @get_args)
    match.nil? ? default_timer_bestpath_limit : match.first.to_i
  end

  def timer_bestpath_limit_always
    match = @@node.config_get("bgp", "timer_bestpath_limit_always", @get_args)
    match.nil? ? default_timer_bestpath_limit_always : true
  end

  # BGP Timers Setters
  def timer_bgp_keepalive_hold_set(keepalive, hold)
    return if workaround_CSCuv52710(keepalive, timer_bgp_keepalive) and
              workaround_CSCuv52710(hold, timer_bgp_holdtime)
    if keepalive == default_timer_bgp_keepalive and
       hold == default_timer_bgp_holdtime
      @set_args[:state], @set_args[:keepalive],
      @set_args[:hold] = "no", keepalive, hold
    else
      @set_args[:state], @set_args[:keepalive],
      @set_args[:hold] = "", keepalive, hold
    end
    @@node.config_set("bgp", "timer_bgp_keepalive_hold", @set_args)
    set_args_keys_default()
  end

  def timer_bestpath_limit_set(seconds, always=false)
    return if workaround_CSCuv52710(seconds, timer_bestpath_limit) and
              workaround_CSCuv52710(always, timer_bestpath_limit_always)
    always ? feature = 'timer_bestpath_limit_always' :
             feature = 'timer_bestpath_limit'
    seconds == default_timer_bestpath_limit ?
      (@set_args[:state], @set_args[:seconds] = "no", "") :
      (@set_args[:state], @set_args[:seconds] = "", seconds)
    @@node.config_set("bgp", feature, @set_args)
    set_args_keys_default()
  end

  # BGP Timers Defaults
  def default_timer_bgp_keepalive_hold
    values = ["#{default_timer_bgp_keepalive}",
              "#{default_timer_bgp_holdtime}"]
  end

  def default_timer_bgp_keepalive
    @@node.config_get_default("bgp", "timer_bgp_keepalive")
  end

  def default_timer_bgp_holdtime
    @@node.config_get_default("bgp", "timer_bgp_hold")
  end

  def default_timer_bestpath_limit
    @@node.config_get_default("bgp", "timer_bestpath_limit")
  end

  def default_timer_bestpath_limit_always
    @@node.config_get_default("bgp", "timer_bestpath_limit_always")
  end
end
end