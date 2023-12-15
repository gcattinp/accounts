// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {IERC20, Points} from "../../src/utils/Points.sol";
import "@forge/Test.sol";

contract PointsTest is Test {
    address alice;
    uint256 alicePk;
    address bob;
    Points points;
    address token;

    uint256 constant POT = 1_000_000_000;

    function setUp() public {
        (alice, alicePk) = makeAddrAndKey("alice");
        bob = makeAddr("bob");
        points = new Points(address(new Signer(alice)), 1);
        token = address(new TestToken(address(points), POT));
    }

    // -- TESTS

    function testDeploy() public {
        new Points(alice, 1);
    }

    function testCheck(uint256 bonus) public {
        vm.assume(bonus < POT);
        uint256 start = 1;
        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(alicePk, keccak256(abi.encodePacked(bob, start, bonus)));
        vm.warp(42);
        uint256 bal = points.check(bob, start, bonus, abi.encodePacked(r, s, v));
        assertEq(bal, bonus + 41);
    }

    function testClaim(uint256 bonus) public {
        vm.assume(bonus < POT);
        uint256 start = 1;
        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(alicePk, keccak256(abi.encodePacked(bob, start, bonus)));
        vm.warp(42);
        vm.prank(bob);
        points.claim(IERC20(token), start, bonus, abi.encodePacked(r, s, v));
        assertEq(TestToken(token).balanceOf(bob), bonus + 41);
    }

    function testFailDoubleClaim(uint256 bonus) public {
        vm.assume(bonus < POT);
        uint256 start = 1;
        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(alicePk, keccak256(abi.encodePacked(bob, start, bonus)));
        vm.warp(42);
        vm.prank(bob);
        points.claim(IERC20(token), start, bonus, abi.encodePacked(r, s, v));
        assertEq(TestToken(token).balanceOf(bob), bonus);
        points.claim(IERC20(token), start, bonus, abi.encodePacked(r, s, v));
    }
}

contract TestToken {
    event Approval(address indexed from, address indexed to, uint256 amount);
    event Transfer(address indexed from, address indexed to, uint256 amount);

    mapping(address => mapping(address => uint256)) public allowance;
    mapping(address => uint256) public balanceOf;
    uint256 totalSupply;

    constructor(address owner, uint256 supply) payable {
        totalSupply = balanceOf[owner] = supply;
    }

    function transfer(address to, uint256 amount) public returns (bool) {
        balanceOf[msg.sender] -= amount;
        unchecked {
            balanceOf[to] += amount;
        }
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address to, uint256 amount) public returns (bool) {
        balanceOf[msg.sender] -= amount;
        unchecked {
            balanceOf[to] += amount;
        }
        emit Transfer(msg.sender, to, amount);
        return true;
    }
}

/// @notice Simple ECDSA-recovered ERC4337 account.
/// @custom:version 0.0.0
contract Signer {
    error Unauthorized();

    address internal immutable _OWNER;
    address internal constant _ENTRYPOINT = 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789;

    constructor(address owner) payable {
        _OWNER = owner;
    }

    function execute(address target, uint256 value, bytes calldata data)
        public
        payable
        returns (bytes memory result)
    {
        if (msg.sender != _OWNER) if (msg.sender != _ENTRYPOINT) revert Unauthorized();
        assembly ("memory-safe") {
            result := mload(0x40)
            calldatacopy(result, data.offset, data.length)
            if iszero(call(gas(), target, value, result, data.length, codesize(), 0x00)) {
                // Bubble up the revert if the call reverts.
                returndatacopy(result, 0x00, returndatasize())
                revert(result, returndatasize())
            }
            mstore(result, returndatasize()) // Store the length.
            let o := add(result, 0x20)
            returndatacopy(o, 0x00, returndatasize()) // Copy the returndata.
            mstore(0x40, add(o, returndatasize())) // Allocate the memory.
        }
    }

    function validateUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    ) external payable returns (uint256 validationData) {
        if (msg.sender != _ENTRYPOINT) revert Unauthorized();
        validationData = this.isValidSignature.selector
            == isValidSignature(_toEthSignedMessageHash(userOpHash), userOp.signature) ? 0 : 1;
        assembly ("memory-safe") {
            if missingAccountFunds {
                pop(call(gas(), caller(), missingAccountFunds, codesize(), 0x00, codesize(), 0x00))
            }
        }
    }

    function isValidSignature(bytes32 hash, bytes calldata signature)
        public
        view
        returns (bytes4 result)
    {
        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly ("memory-safe") {
            r := calldataload(signature.offset)
            s := calldataload(add(signature.offset, 0x20))
            v := byte(0, calldataload(add(signature.offset, 0x40)))
        }
        if (_OWNER == ecrecover(hash, v, r, s)) result = this.isValidSignature.selector;
    }

    function _toEthSignedMessageHash(bytes32 hash) internal pure returns (bytes32 result) {
        assembly ("memory-safe") {
            mstore(0x20, hash)
            mstore(0x00, "\x00\x00\x00\x00\x19Ethereum Signed Message:\n32")
            result := keccak256(0x04, 0x3c)
        }
    }

    fallback() external payable {
        assembly ("memory-safe") {
            if callvalue() { return(0x00, 0x00) }
            mstore(0x20, shr(224, calldataload(0)))
            return(0x3C, 0x20)
        }
    }

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
}
