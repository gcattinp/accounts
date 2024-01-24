# PaymentValidator
[Git Source](https://github.com/NaniDAO/accounts/blob/7ac59b02001a809e2cf6d349a24270ca5342f835/src/validators/PaymentValidator.sol)

**Author:**
nani.eth (https://github.com/NaniDAO/accounts/blob/main/src/validators/PaymentValidator.sol)

Simple payment plan validator for smart accounts.


## State Variables
### _authorizers
========================== STORAGE ========================== ///

*Stores mappings of authorizers to accounts.*


```solidity
mapping(address => address[]) internal _authorizers;
```


### _plans
*Stores mappings of asset payment plans to accounts.*


```solidity
mapping(address => mapping(address => Plan)) internal _plans;
```


## Functions
### constructor

======================== CONSTRUCTOR ======================== ///

*Constructs
this implementation.*


```solidity
constructor() payable;
```

### validateUserOp

=================== VALIDATION OPERATIONS =================== ///

*Validates ERC4337 userOp with additional auth logic flow among authorizers.*


```solidity
function validateUserOp(UserOperation calldata userOp, bytes32 userOpHash, uint256)
    public
    payable
    virtual
    returns (uint256 validationData);
```

### getAuthorizers

=================== AUTHORIZER OPERATIONS =================== ///

*Returns the authorizers for an account.*


```solidity
function getAuthorizers(address account) public view virtual returns (address[] memory);
```

### getPlan

*Returns an asset payment plan for an account.*


```solidity
function getPlan(address account, address asset) public view virtual returns (Plan memory);
```

### setAuthorizers

*Sets the new authorizers for the caller account.*


```solidity
function setAuthorizers(address[] calldata authorizers) public payable virtual;
```

### setPlan

*Sets an asset payment plan for the caller account.*


```solidity
function setPlan(address asset, Plan calldata plan) public payable virtual;
```

### install

================== INSTALLATION OPERATIONS ================== ///

*Installs the new authorizers and spending plans for the caller account.*


```solidity
function install(address[] calldata authorizers, address[] calldata assets, Plan[] calldata plans)
    public
    payable
    virtual;
```

### uninstall

*Uninstalls the authorizers for the caller account.*


```solidity
function uninstall() public payable virtual;
```

## Events
### AuthorizersSet
=========================== EVENTS =========================== ///

*Logs the new authorizers for an account.*


```solidity
event AuthorizersSet(address indexed account, address[] authorizers);
```

### PlanSet
*Logs the new asset spending plans for an account.*


```solidity
event PlanSet(address indexed account, address asset, Plan plan);
```

## Errors
### InvalidAllowance
======================= CUSTOM ERRORS ======================= ///

*Spend exceeds the planned allowance for asset.*


```solidity
error InvalidAllowance();
```

### InvalidTimestamp
*Spend is outside planned time range for asset.*


```solidity
error InvalidTimestamp();
```

### InvalidETHCalldata
*Calldata is attached to an ether (ETH) spend.*


```solidity
error InvalidETHCalldata();
```

### InvalidCalldata
*Invalid calldata is attached to asset spend.*


```solidity
error InvalidCalldata();
```

## Structs
### Plan
========================== STRUCTS ========================== ///

*Asset spending plan struct.*


```solidity
struct Plan {
    uint192 allowance;
    uint32 validAfter;
    uint32 validUntil;
    address[] validTo;
}
```

### UserOperation
*The ERC4337 user operation (userOp) struct.*


```solidity
struct UserOperation {
    address sender;
    uint256 nonce;
    bytes initCode;
    bytes callData;
    uint256 callGasLimit;
    uint256 verificationGasLimit;
    uint256 preVerificationGas;
    uint256 maxFeePerGas;
    uint256 maxPriorityFeePerGas;
    bytes paymasterAndData;
    bytes signature;
}
```
