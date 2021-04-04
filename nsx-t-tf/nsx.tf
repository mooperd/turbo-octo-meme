terraform {
  required_providers {
    nsxt = {
      source = "vmware/nsxt"
    }
  }
}

provider "nsxt" {
  allow_unverified_ssl  = true
  remote_auth           = true
  max_retries           = 10
  retry_min_delay       = 500
  retry_max_delay       = 5000
  retry_on_status_codes = [429]
}

data "nsxt_policy_transport_zone" "overlay" {
    display_name = "overlay"
}

data "nsxt_policy_tier0_gateway" "t0-gw" {
    display_name = "t0-gw"
}

data "nsxt_policy_tier1_gateway" "t1-gw1" {
    display_name = "t1-gw1"
}

data "nsxt_policy_dhcp_server" "dhcp-server" {
    display_name = "dhcp-server"
}

data "nsxt_policy_edge_cluster" "edge-cluster" {
    display_name = "edge-cluster"
}



// segments

resource "nsxt_policy_segment" "management-segment" {
  display_name        = "management-segment"
  description         = "Terraform provisioned Segment"
  connectivity_path   = data.nsxt_policy_tier1_gateway.t1-gw1.path
  transport_zone_path = data.nsxt_policy_transport_zone.overlay.path

  subnet {
    cidr        = "10.141.0.1/24"
    dhcp_ranges = ["10.141.0.50-10.141.0.250"]

    dhcp_v4_config {
      server_address = "10.141.0.2/24"
      lease_time     = 36000
    }
  }
  tag {
    scope = "cluster"
    tag   = "cluster02"
  }
}

resource "nsxt_policy_segment" "application-segment" {
  display_name        = "application-segment"
  description         = "Terraform provisioned Segment"
  connectivity_path   = data.nsxt_policy_tier1_gateway.t1-gw1.path
  transport_zone_path = data.nsxt_policy_transport_zone.overlay.path

  subnet {
    cidr        = "10.141.11.1/24"
    dhcp_ranges = ["10.141.11.50-10.141.11.250"]

    dhcp_v4_config {
      server_address = "10.141.11.2/24"
      lease_time     = 36000
    }
  }
  tag {
    scope = "cluster"
    tag   = "cluster02"
  }
}

resource "nsxt_policy_segment" "database-segment" {
  display_name        = "database-segment"
  description         = "Terraform provisioned Segment"
  connectivity_path   = data.nsxt_policy_tier1_gateway.t1-gw1.path
  transport_zone_path = data.nsxt_policy_transport_zone.overlay.path

  subnet {
    cidr        = "10.141.10.1/24"
    dhcp_ranges = ["10.141.10.50-10.141.10.250"]

    dhcp_v4_config {
      server_address = "10.141.10.2/24"
      lease_time     = 36000
    }
  }
  tag {
    scope = "cluster"
    tag   = "cluster02"
  }
}

// NAT

resource "nsxt_policy_nat_rule" "management-segment-snat" {
  display_name         = "management-segment-snat"
  action               = "SNAT"
  source_networks      = ["10.141.0.0/24"]
  translated_networks  = ["87.106.186.30"]
  gateway_path         = data.nsxt_policy_tier1_gateway.t1-gw1.path
  logging              = false
  tag {
    scope = "type"
    tag   = "management"
  }
}

resource "nsxt_policy_nat_rule" "application-segment-snat" {
  display_name         = "application-segment-snat"
  action               = "SNAT"
  source_networks      = ["10.141.11.0/24"]
  translated_networks  = ["87.106.186.30"]
  gateway_path         = data.nsxt_policy_tier1_gateway.t1-gw1.path
  logging              = false

  tag {
    scope = "type"
    tag   = "application"
  }
}


resource "nsxt_policy_nat_rule" "database-segment-snat" {
  display_name         = "database-segment-snat"
  action               = "SNAT"
  source_networks      = ["10.141.10.0/24"]
  translated_networks  = ["87.106.186.30"]
  gateway_path         = data.nsxt_policy_tier1_gateway.t1-gw1.path
  logging              = false

  tag {
    scope = "type"
    tag   = "database"
  }
}


/* Probably NS groups are not what we want.
resource "nsxt_ns_group" "cluster02-ns-group" {
  description  = "NG provisioned by Terraform"
  display_name = "cluster02-ns-group"

  membership_criteria {
    target_type = "LogicalSwitch"
    scope       = "cluster"
    tag         = "cluster02"
  }

  tag {
    scope = "cluster"
    tag   = "cluster02"
  }
}
*/

resource "nsxt_policy_group" "application-group" {
  display_name = "application-group"
  description  = "Terraform provisioned Group"

  criteria {
    condition {
      key         = "Tag"
      member_type = "Segment"
      operator    = "EQUALS"
      value       = "type|application"
    }
  } 
}


resource "nsxt_policy_lb_pool" "cluster02-lb-pool" {
  display_name         = "cluster02-lb-pool"
  description          = "Terraform provisioned LB Pool"
  algorithm            = "ROUND_ROBIN"
  min_active_members   = 1
  active_monitor_path  = "/infra/lb-monitor-profiles/default-icmp-lb-monitor"
  passive_monitor_path = "/infra/lb-monitor-profiles/default-passive-lb-monitor"
  member_group {
     group_path = nsxt_policy_group.application-group.path
  }
  snat {
    type = "AUTOMAP"
  }
  tcp_multiplexing_enabled = true
  tcp_multiplexing_number  = 8
}

data "nsxt_policy_lb_app_profile" "default-tcp-lb-app-profile" {
  type         = "TCP"
  display_name = "default-tcp-lb-app-profile"
}

resource "nsxt_policy_lb_service" "cluster02-lb-service" {
  display_name      = "cluster02-lb-service"
  description       = "Terraform provisioned Service"
  connectivity_path = data.nsxt_policy_tier1_gateway.t1-gw1.path
  size              = "SMALL"
  enabled           = true
  error_log_level   = "ERROR"
  # depends_on        = [nsxt_policy_tier1_gateway_interface.tier1_gateway_interface]
}

resource "nsxt_policy_lb_virtual_server" "cluster02-lb-virtual-server" {
  display_name               = "cluster02-lb-virtual-server"
  description                = "Terraform provisioned Virtual Server"
  access_log_enabled         = true
  application_profile_path   = data.nsxt_policy_lb_app_profile.default-tcp-lb-app-profile.path
  enabled                    = true
  ip_address                 = "87.106.186.12"
  ports                      = ["80"]
  default_pool_member_ports  = ["30080"]
  service_path               = nsxt_policy_lb_service.cluster02-lb-service.path
  max_concurrent_connections = 100
  max_new_connection_rate    = 100
  pool_path                  = nsxt_policy_lb_pool.cluster02-lb-pool.path
}



