/*
 * Copyright 2017 Google Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

data "template_file" "proxy-startup-script" {
  template = file(format("%s/config/startup.sh", path.module))

  vars = {
    squid_enabled       = "true"
    squid_config        = templatefile(
      var.squid_config_tmpl == "" ? "${path.module}/config/squid.conf.tmpl" : var.squid_config_tmpl,
      { PROXY_PORT = var.proxy_port }
    )
    debug_utils_enabled = var.debug_utils_enabled
    stackdriver_monitoring_enabled = var.stackdriver_monitoring_enabled
    stackdriver_logging_enabled = var.stackdriver_logging_enabled
  }
}

locals {
  zone                          = var.zone == "" ? lookup(var.region_params[var.region], "zone") : var.zone
  name                          = "${var.name}proxy-${local.zone}"
  generated_proxy_instance_tags = ["inst-${local.zonal_tag}", "inst-${local.regional_tag}"]
  zonal_tag                     = "${var.name}proxy-${local.zone}"
  regional_tag                  = "${var.name}proxy-${var.region}"
  network_project               = var.network_project == "" ? var.project : var.network_project
}

module "instance_template" {
  source           = "terraform-google-modules/vm/google//modules/instance_template"
  version          = "~> v6.3.0"
  project_id         = var.project
  region             = var.region
  subnetwork         = var.subnetwork
  subnetwork_project = var.project
  can_ip_forward     = true
  tags               = compact(concat(local.generated_proxy_instance_tags, var.proxy_instance_tags))
  labels             = var.instance_labels
  service_account = {
    email  = var.service_account_email
    scopes = var.access_scopes
  }
  machine_type         = var.machine_type
  name_prefix          = local.name
  source_image_family  = var.compute_image
  source_image_project = var.compute_family
  startup_script       = data.template_file.proxy-startup-script.rendered
  metadata             = var.metadata
  access_config = [{
    # Auto assign ips
    nat_ip = null
    network_tier = "PREMIUM"
  }]
}


module "proxy-mig" {
  # Waiting for 5.1 release
  source           = "terraform-google-modules/vm/google//modules/mig"
  version          = "~> v6.3.0"
  project_id         = var.project
  region             = var.region
  network            = var.network
  subnetwork         = var.subnetwork
  subnetwork_project = var.project
  hostname           = local.name
  instance_template  = module.instance_template.self_link
  # Set to null since number of instances is controlled by number of attached
  # google_compute_region_per_instance_configs
  target_size        = null
  update_policy = [{
    instance_redistribution_type = "NONE"
    type                         = "OPPORTUNISTIC"
    minimal_action               = "REPLACE"
    max_surge_fixed              = 0
    max_surge_percent            = null
    max_unavailable_fixed        = 3
    max_unavailable_percent      = null
    min_ready_sec                = 30
  }]
  distribution_policy_zones = [local.zone]
}


resource "google_compute_region_per_instance_config" "proxy" {
  provider = google-beta
  count = var.size

  region = module.proxy-mig.instance_group_manager.region
  region_instance_group_manager = module.proxy-mig.instance_group_manager.name

  name = "${local.name}-${count.index}"
  preserved_state {
    metadata = {
      index = count.index
    }
  }
}

resource "google_compute_firewall" "proxies-ingress" {
  name    = local.zonal_tag
  network = var.network
  project = local.network_project

  allow {
    protocol = "tcp"
    ports    = [var.proxy_port]
  }

  source_ranges = var.allowed_source_ranges
  source_tags = var.use_target_tags ? compact(concat(list(local.regional_tag, local.zonal_tag), var.allowed_source_tags)) : []
  target_tags = local.generated_proxy_instance_tags
}

resource "google_compute_firewall" "proxy-vm-ssh" {
  count = length(var.ssh_source_ranges) > 0 ? 1 : 0

  name    = "${local.zonal_tag}-ssh"
  network = var.network
  project = local.network_project

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = var.ssh_source_ranges
  target_tags = local.generated_proxy_instance_tags
}

