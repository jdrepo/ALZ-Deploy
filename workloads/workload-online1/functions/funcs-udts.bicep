@export()
@description('Function to extract resource information from a resource ID.')
func funcGetResourceInformation(resourceId string) resourceInformationType => {
  subscriptionId: split(resourceId, '/')[2]
  resourceGroupName: split(resourceId, '/')[4]
  resourceName: last(split(resourceId, '/'))
}

@export()
type resourceInformationType = {
  subscriptionId: string
  resourceGroupName: string
  resourceName: string
}
