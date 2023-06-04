resource "azurerm_redis_enterprise_cluster" "global_replicas" {
  for_each            = toset(var.stamps)
  name                = "${local.prefix}-${each.value}-redis"
  resource_group_name = azurerm_resource_group.global.name
  location            = each.value

  zones = ["1", "2", "3"]

  sku_name = "Enterprise_E10-2"
}

resource "azurerm_redis_enterprise_database" "default" {
  name = "default"

  cluster_id        = azurerm_redis_enterprise_cluster.global_replicas[var.stamps[0]].id # take the first location from the list of stamps
  client_protocol   = "Encrypted"
  clustering_policy = "EnterpriseCluster"
  eviction_policy   = "NoEviction"
  port              = 10000

  linked_database_id = [for location in var.stamps : "${azurerm_redis_enterprise_cluster.global_replicas[location].id}/databases/default"]

  linked_database_group_nickname = "geoReplicas"
}