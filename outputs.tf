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

output proxy_instance_tags {
  description = "The tag in use by the NAT Gateway instances"
  value       = local.generated_proxy_instance_tags
}

output proxy_instance_group_name {
  description = "The name of the instance group. Names of individual instances can be obtained by appending -$INDXEX to this name."
  value       = local.name
}

# output squid_port {
#   description = "The name of the instance group. Names of individual instances can be obtained by appending -$INDXEX to this name."
#   value       = local.name
# }
