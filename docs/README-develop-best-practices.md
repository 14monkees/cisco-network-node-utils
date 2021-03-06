# Develoment Best Practices for cisco_node_utils APIs.

* [Overview](#overview)
* [YAML Development Best Practices](#ydbp)
* [Common Object Development Best Practices](#odbp)
* [MiniTest Development Best Practices](#mdbp)

## <a name="overview">Overview</a>

This document is intended to assist in developing cisco_node_utils API's that are consistent with current best practices.


## <a name="ydbp">YAML Development Best Practices</a>

* [Y1](#yaml1): All yaml feature entries should be kept in alphabetical order.
* [Y2](#yaml2): Use *regexp* anchors where needed for `config_get` and `config_get_token` entries.
* Y3: Avoid nested optional matches.
* [Y4](#yaml4): Use the `_template` feature when getting/setting the same property value at multiple levels.
* [Y5](#yaml5): When possible include a `default_value` that represents the system default value.
* [Y6](#yaml6): When possible, use the same `config_get` show command for all properties and document any anomalies.
* [Y7](#yaml7): Use Key-value wildcards instead of Printf-style wildcards.
* [Y8](#yaml8): Selection of `show` commands for `config_get`.



## <a name="odbp">Common Object Development Best Practices</a>

* [CO1](#co1): Features that can be configured under the global and non-global vrfs need to account for this in the object design.
* [CO2](#co2): Make use of the equality operator allowing proper `instance1 == instance2` checks in the minitests.
* [CO3](#co3): Use `''` rather than `nil` to represent "property is absent entirely"
* [CO4](#co4): Make sure all new properites have a `getter`, `setter` and `default_getter` method.
* [CO5](#co5): Use singleton-like design for resources that cannot have multiple instances.

## <a name="mdbp">MiniTest Development Best Practices</a>

* [MT1](#mt1): Ensure that **all new API's** have minitest coverage.
* [MT2](#mt2): Use appropriate `assert_foo` and `refute_foo` statements rather than `assert_equal`.
* [MT3](#mt3): Do not hardcode interface names.
* [MT4](#mt4): Make use of the `config` helper method for device configuration instead of `@device.cmd`.
* [MT5](#mt5): Make use of the `assert_show_match` and `refute_show_match` helper methods to validate expected outcomes in the CLI instead of `@device.cmd("show...")`.



## YAML Best Practices:

### <a name="yaml1">Y1: All yaml feature entries should be kept in alphabetical order.

Please keep all feature names in alphabetical order, and all options under a feature in alphabetical order as well. As YAML permits duplicate entries (in which case the last entry overrides any earlier entries), keeping a consistent order helps to prevent accidentally introducing such duplication.

Top level features in alpabetical order:

```
aaa_authentication_login:
...
dnsclient:
...
interface:
```

Options under a feature:

```
interface:
  access_vlan:
    ...
  all_interfaces:
    ...
  create:
    ...
  description:
    ...  
```

### <a name="yaml2">Y2: Use *regexp* anchors where needed for `config_get` and `config_get_token` entries.

Please use *regexp* anchors `^$` to ensure you match the correct feature information in the `show` output.

```
syslog_settings:
  timestamp:
    config_get: "show running-config all | include '^logging timestamp'"
    config_get_token: '/^logging timestamp (.*)$/'
    config_set: '<state> logging timestamp <units>'
    default_value: 'seconds'
```

### <a name="yaml3">Y3: Avoid nested optional matches.

### <a name="yaml4">Y4: Use the `_template` feature when getting/setting the same property value at multiple levels.

Using the template below, `auto_cost` and `default_metric` can be set under `router ospf foo` and `router ospf foo; vrf blue`.

```
ospf:
  _template:
    config_get: "show running ospf all"
    config_get_token: '/^router ospf <name>$/'
    config_get_token_append:
      - '/^vrf <vrf>$/'
    config_set: "router ospf <name>"
    config_set_append:
      - "vrf <vrf>"

  auto_cost:
    config_get_token_append: '/^auto-cost reference-bandwidth (\d+)\s*(\S+)?$/'
    config_set_append: "auto-cost reference-bandwidth <cost> <type>"
    default_value: [40, "Gbps"]

  default_metric:
    config_get_token_append: '/^default-metric (\d+)?$/'
    config_set_append: "<state> default-metric <metric>"
    default_value: 0
```

### <a name="yaml5">Y5: When possible include a `default_value` that represents the system default value.

Please make sure to specify a `default_value` and document properties that don't have a system default.  System defaults may differ between cisco platforms making it important to define for lookup in the cisco_node_utils common object methods.


Default value for `message_digest_alg_type` is `md5`

```
message_digest_alg_type:
    config_get: 'show running interface all'
    config_get_token: ['/^interface %s$/i', '/^\s*ip ospf message-digest-key \d+ (\S+)/']
    default_value: 'md5'
```

**NOTE1: Use strings rather then symbols when applicable**.

If the `default_value` differs between cisco platforms, the more specific `command_reference_[platform].yaml` file should be used.

For example, if the default value on all platforms except the n9k is `md5` then set the entry in `command_reference_common.yaml` to `md5` and set the entry in `command_reference_n9k.yaml` to it's default `sha2`.

### <a name="yaml6">Y6: When possible, use the same `config_get` show command for all properties and document any anomalies.

All properties below use the `show run tacacs all` command except `directed_request` which is documented.

```
tacacs_server:
  deadtime:
    config_get: "show run tacacs all"
    config_get_token: '/^tacacs-server deadtime\s+(\d+)/'
    config_set: "%s tacacs-server deadtime %d"
    default_value: 0

  directed_request:
    # oddly, directed request must be retrieved from aaa output
    config_get: "show running aaa all"
    config_get_token: '/(?:no)?\s*tacacs-server directed-request/'
    config_set: "%s tacacs-server directed-request"
    default_value: false

  encryption_type:
    config_get: "show run tacacs all"
    config_get_token: '/^tacacs-server key (\d+)\s+(\S+)/'
    default_value: 0

  encryption_password:
    config_get: "show run tacacs all"
    config_get_token: '/^tacacs-server key (\d+)\s+(\S+)/'
    default_value: ""
```

### <a name="yaml7">Y7: Use Key-value wildcards instead of Printf-style wildcards.

The following approach is moderately more complex to implement but is more readable in the ruby code and is flexible enough to handle significant platform differences in CLI. It is therefore the recommended approach for new development.

**Key-value wildcards**

```
config_set_append: "<state> log-adjacency-changes <type>"
```

This following approach is quick to implement and concise, but less flexible - in particular it cannot handle a case where different platforms take parameters in a different order - and less readable in the ruby code.

**Printf-style wildcards**

```
config_set_append: "%s log-adjacency-changes %s"
```

### <a name="yaml8">Y8: Selection of `show` commands for `config_get`.

The following commands should be preferred over `show [feature]` commands since not all `show [feature]` commands behave in the same manner across cisco platforms.

* `show running [feature] all` if available.
* `show running all` if `show running [feature] all` is *not* available.


## Common Object Best Practices:

### <a name="co1">CO1: Features that can be configured under the global and non-global vrfs need to account for this in the object design.

Many cisco features can be configured under the default or global vrf and also under *n* number of non-default vrfs.

The following `initialize` and `self.vrfs` methods account for configuration under `default` and `non-default vrfs`.

```
    def initialize(router, name, instantiate=true)
      fail TypeError if router.nil?
      fail TypeError if name.nil?
      fail ArgumentError unless router.length > 0
      fail ArgumentError unless name.length > 0
      @router = router
      @name = name
      @parent = {}
      if @name == 'default'
        @get_args = @set_args = { name: @router }
      else
        @get_args = @set_args = { name: @router, vrf: @name }
      end

      create if instantiate
    end

    # Create a hash of all router ospf vrf instances
    def self.vrfs
      hash_final = {}
      RouterOspf.routers.each do |instance|
        name = instance[0]
        vrf_ids = config_get('ospf', 'vrf', name: name)
        hash_tmp = { name =>
          { 'default' => RouterOspfVrf.new(name, 'default', false) } }
        unless vrf_ids.nil?
          vrf_ids.each do |vrf|
            hash_tmp[name][vrf] = RouterOspfVrf.new(name, vrf, false)
          end
        end
        hash_final.merge!(hash_tmp)
      end
      hash_final
    end
```

### <a name="co2">CO2: Make use of the equality operator allowing proper `instance1 == instance2` checks in the minitests.

Having this logic defined in the common object lets the minitest easily check the specific instances.

Without this equality operator `==` only passes if they are the same instance object.  With this equality operator `==` passes if they are different objects referring to the same configuration on the node.

```
  def ==(other)
    (name == other.name) && (vrf == other.vrf)
  end
```

Example Usage:

```
  def test_dnsdomain_create_destroy_multiple
    id1 = 'aoeu.com'
    id2 = 'asdf.com'
    refute_includes(Cisco::DnsDomain.dnsdomains, id1)
    refute_includes(Cisco::DnsDomain.dnsdomains, id2)

    ns1 = Cisco::DnsDomain.new(id1)
    ns2 = Cisco::DnsDomain.new(id2)
    assert_includes(Cisco::DnsDomain.dnsdomains, id1)
    assert_includes(Cisco::DnsDomain.dnsdomains, id2)
    assert_equal(Cisco::DnsDomain.dnsdomains[id1], ns1)
    assert_equal(Cisco::DnsDomain.dnsdomains[id2], ns2)

    ns1.destroy
    refute_includes(Cisco::DnsDomain.dnsdomains, id1)
    assert_includes(Cisco::DnsDomain.dnsdomains, id2)
    ns2.destroy
    refute_includes(Cisco::DnsDomain.dnsdomains, id2)
  end
```
### <a name="co3">CO3: Use `''` rather than `nil` to represent "property is absent entirely"

Our convention is to let `''` represent 'not configured at all' rather than `nil`. For example, `interface.rb`:

```
def vrf
  vrf = config_get('interface', 'vrf', @name)
  return '' if vrf.nil?
  vrf.shift.strip
end

def vrf=(vrf)
  fail TypeError unless vrf.is_a?(String)
  if vrf.empty?
    config_set('interface', 'vrf', @name, 'no', '')
  else
    config_set('interface', 'vrf', @name, '', vrf)
  end
```

However, if a property has a default value (it is never truly 'removed'), then we should do this instead:

```
def access_vlan
  vlan = config_get('interface', 'access_vlan', @name)
  return default_access_vlan if vlan.nil?
  vlan.shift.to_i
end

def access_vlan=(vlan)
  config_set('interface', 'access_vlan', @name, vlan)
```

### <a name="co4">CO4: Make sure all new properites have a `getter`, `setter` and `default_getter` method.

In order to have a complete set of api's for each property it is important that all properties have a `getter`, `setter` and `default_getter` method.

This can be seen in the following `router_id` property.

```
# Getter Method
def router_id
  match = config_get('ospf', 'router_id', @get_args)
  match.nil? ? default_router_id : match.first
end

# Setter Method
def router_id=(router_id)
  if router_id == default_router_id
    @set_args[:state] = 'no'
    @set_args[:router_id] = ''
  else
    @set_args[:state] = ''
    @set_args[:router_id] = router_id
  end

  config_set('ospf', 'router_id', @set_args)
  delete_set_args_keys([:state, :router_id])
end

# Default Getter Method
def default_router_id
  config_get_default('ospf', 'router_id')
end
```

### <a name="co5">CO5: Use singleton-like design for resources that cannot have multiple instances.

See [TacacsServer](../lib/cisco_node_utils/tacacs_server.rb) and [SnmpServer](../lib/cisco_node_utils/snmpserver.rb) for examples.

## MiniTest Best Practices:

### <a name="mt1">MT1: Ensure that *all new API's* have minitest coverage.

### <a name="mt2">MT2: Use appropriate `assert_foo` and `refute_foo` statements rather than `assert_equal`.


Minitest has a bunch of different test methods that are more specific than assert_equal. See [test methods](http://docs.ruby-lang.org/en/2.1.0/MiniTest/Assertions.html) for a complete list, but here are some general guidelines:

| Instead of ...                | Use ...           |
| ------------------------------|:-----------------:|
| assert_equal(true, foo.bar?)  | assert(foo.bar?)  |
| assert_equal(false, foo.bar?) | refute(foo.bar?)  |
| assert_equal(true, foo.nil?)  | assert_nil(foo)   |
| assert_equal(false, foo.nil?) | refute_nil(foo)   |
| assert_equal(true, foo.empty?)| assert_empty(foo) |

The more specific assertions also produce more helpful failure messages if something is wrong.

### <a name="mt3">MT3: Do not hardcode interface names.

Rather then hardcode an interface name that may or may not exist, instead use 
the `interfaces[]` array.

```
def create_interface(ifname=interfaces[0])
  @default_show_command = show_cmd(ifname)
  Interface.new(ifname)
end
```

If additional interfaces are needed array index `1` and `2` may be used.

### <a name="mt4">MT4: Make use of the `config` helper method for device configuration instead of `@device.cmd`.

For conveninence the `config` helper method has been provided for device configuration within the minitests.

```
config('no feature ospf')
```

```
config('feature ospf'; 'router ospf green')
```

### <a name="mt5">MT5: Make use of the `assert_show_match` and `refute_show_match` helper methods to validate expected outcomes in the CLI instead of `@device.cmd("show...")`.

We have a very common pattern in minitest where we execute some show command over the telnet connection, match it against some regexp pattern, and succeed or fail based on the result. Helper methods `assert_show_match` and `refute_show_match` support this pattern.

```
assert_show_match(command: 'show run all | no-more',
                  pattern: /interface port-channel 1/,
                  msg:     'port-channel is not present but it should be')
```

If your `command` and/or `pattern` are the same throughout a test case or throughout a test suite, you can set the test case instance variables `@default_show_command` and/or `@default_output_pattern` which serve as defaults for these parameters:

```
@default_show_command = 'show run interface all | include "interface" | no-more'
assert_output_match(pattern: /interface port-channel 10/)
refute_output_match(pattern: /interface port-channel 11/)
refute_output_match(pattern: /interface port-channel 12/)
assert_output_match(pattern: /interface port-channel 13/)
```
