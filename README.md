# HelloID-Conn-Prov-Target-Altiplano-MyDMS

> [!IMPORTANT]
> This connector has been upgraded to a HelloID PowerShell v2 connector and refactored to meet the latest standards. Please note that it was updated without a working test environment, so we recommend validating it during implementation.


> [!IMPORTANT]
> This repository contains the connector and configuration code only. The implementer is responsible to acquire the connection details such as username, password, certificate, etc. You might even need to sign a contract or agreement with the supplier before implementing this connector. Please contact the client's application manager to coordinate the connector requirements.

<p align="center">
  <img src="https://www.altiplano.nl/wp-content/uploads/2022/11/Altiplano_BV.svg">
</p>

## Table of contents

- [HelloID-Conn-Prov-Target-Altiplano-MyDMS](#helloid-conn-prov-target-altiplano-mydms)
  - [Table of contents](#table-of-contents)
  - [Introduction](#introduction)
  - [Supported features](#supported-features)
  - [Getting started](#getting-started)
    - [HelloID Icon URL](#helloid-icon-url)
    - [Requirements](#requirements)
    - [Connection settings](#connection-settings)
    - [Correlation configuration](#correlation-configuration)
    - [Field mapping](#field-mapping)
    - [Account Reference](#account-reference)
  - [Remarks](#remarks)
    - [Account lifecycle behavior](#account-lifecycle-behavior)
    - [Reboarding](#reboarding)
  - [Development resources](#development-resources)
    - [API endpoints](#api-endpoints)
    - [API documentation](#api-documentation)
  - [Getting help](#getting-help)
  - [HelloID docs](#helloid-docs)

## Introduction

_HelloID-Conn-Prov-Target-Altiplano-MyDMS_ is a _target_ connector. _MyDMS_ provides a set of REST APIs that allow you to programmatically interact with its data.

## Supported features

The following features are available:

| Feature                                   | Supported | Actions                                 | Remarks |
| ----------------------------------------- | --------- | --------------------------------------- | ------- |
| **Account Lifecycle**                     | ✅         | Create, Update, Enable, Disable, Delete |         |
| **Permissions**                           | ✅         | Retrieve, Grant, Revoke                 |         |
| **Resources**                             | ❌         | -                                       |         |
| **Entitlement Import: Accounts**          | ❌         | -                                       |         |
| **Entitlement Import: Permissions**       | ❌         | -                                       |         |
| **Governance Reconciliation Resolutions** | ❌         | -                                       |         |


## Getting started

### HelloID Icon URL
URL of the icon used for the HelloID Provisioning target system.
```
https://raw.githubusercontent.com/Tools4everBV/HelloID-Conn-Prov-Target-Altiplano-MyDMS/refs/heads/main/Icon.png
```

### Requirements


### Connection settings

The following settings are required to connect to the API.

| Setting  | Description                        | Mandatory |
| -------- | ---------------------------------- | --------- |
| UserName | The UserName to connect to the API | Yes       |
| Password | The Password to connect to the API | Yes       |
| BaseUrl  | The URL to the API                 | Yes       |

### Correlation configuration

The correlation configuration is used to specify which properties will be used to match an existing account within _MyDMS_ to a person in _HelloID_.

| Setting                   | Value                             |
| ------------------------- | --------------------------------- |
| Enable correlation        | `True`                            |
| Person correlation field  | `PersonContext.Person.ExternalId` |
| Account correlation field | `employeeNr`                      |

> [!TIP]
> _For more information on correlation, please refer to our correlation [documentation](https://docs.helloid.com/en/provisioning/target-systems/powershell-v2-target-systems/correlation.html) pages_.

### Field mapping

The field mapping can be imported by using the _fieldMapping.json_ file.

### Account Reference

The account reference is populated with the property `_id` from _MyDMS_.

## Remarks

### Account lifecycle behavior
- `Disable` and `Delete` are soft actions that set `_endEmployment` to yesterday.
- `Enable` clears `_endEmployment` and sets `_startEmployment`.

### Reboarding
When an account is deleted, a soft-delete action is performed. Please note this when reboarding users or reusing previously used email addresses or userPrincipalName values, as this might cause issues.

## Development resources

### API endpoints

The following endpoints are used by the connector

| Endpoint                        | HTTP Method | Description                                             |
| ------------------------------- | ----------- | ------------------------------------------------------- |
| /user                           | GET, POST   | Retrieve, Create and update user information                 |
| /user?id={id}&groupId={groupId} | PUT         | Grant group permission to account                       |
| /user?id={id}&groupId={groupId} | DELETE      | Revoke group permission from account                    |
| /group/list                     | GET         | Retrieve permissions and import permission entitlements |

### API documentation

[Provisioning API Postman Documenter](https://documenter.getpostman.com/view/2535904/UVkiRHwA#52d83a95-93ef-4945-82bb-d39070dc0ef9)

## Getting help

> [!TIP]
> _For more information on how to configure a HelloID PowerShell connector, please refer to our [documentation](https://docs.helloid.com/en/provisioning/target-systems/powershell-v2-target-systems.html) pages_.

## HelloID docs

The official HelloID documentation can be found at: https://docs.helloid.com/
