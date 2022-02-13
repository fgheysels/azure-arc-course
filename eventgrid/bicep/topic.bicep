targetScope='resourceGroup'
param name string = 'topic123abc'
param location string = resourceGroup().location
param customLocation string 

resource topic 'Microsoft.EventGrid/topics@2020-10-15-preview' = {
  name: name
  location: location
  kind: 'AzureArc'
  extendedLocation: {
    name: customLocation
    type: 'CustomLocation'
  }
  tags: {
    type: 'kubernetes'
    env: 'dev'
  }
  properties: {
    inputSchema: 'CloudEventSchemaV1_0'
  }
}

resource sub 'Microsoft.EventGrid/eventSubscriptions@2020-10-15-preview' = {
  name: 'webhook'
  scope: topic
  properties: {
    destination: {
      endpointType: 'WebHook'
      properties: {
        endpointUrl: 'https://gebaevents.azurewebsites.net/api/updates'
      }
    }
    eventDeliverySchema: 'CloudEventSchemaV1_0'
  }
}
