// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import "@forge/Test.sol";
import "@solady/test/utils/mocks/MockERC20.sol";
import "@solady/test/utils/mocks/MockERC721.sol";
import "@solady/test/utils/mocks/MockERC1155.sol";
import "@solady/test/utils/mocks/MockERC6909.sol";

import {Account as NaniAccount} from "../../src/Account.sol";
import {ITokenOwner, ITokenAuth, Owners} from "../../src/ownership/Owners.sol";

contract MockERC721TotalSupply is MockERC721 {
    uint256 public totalSupply;

    constructor() payable {}

    function mint(address to, uint256 id) public virtual override(MockERC721) {
        _mint(to, id);

        unchecked {
            ++totalSupply;
        }
    }
}

contract MockERC1155TotalSupply is MockERC1155 {
    mapping(uint256 => uint256) public totalSupply;

    constructor() payable {}

    function mint(address to, uint256 id, uint256 amount, bytes memory)
        public
        virtual
        override(MockERC1155)
    {
        _mint(to, id, amount, "");

        totalSupply[id] += amount;
    }
}

contract MockERC6909TotalSupply is MockERC6909 {
    mapping(uint256 => uint256) public totalSupply;

    constructor() payable {}

    function mint(address to, uint256 id, uint256 amount)
        public
        payable
        virtual
        override(MockERC6909)
    {
        _mint(to, id, amount);

        totalSupply[id] += amount;
    }
}

contract OwnersTest is Test {
    address internal alice;
    uint256 internal alicePk;
    address internal bob;
    uint256 internal bobPk;
    address internal chuck;
    uint256 internal chuckPk;
    address internal dave;
    uint256 internal davePk;

    address internal erc20;
    address internal erc721;
    address internal erc1155;
    address internal erc6909;

    NaniAccount internal account;
    Owners internal owners;
    address internal entryPoint = 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789;

    uint256 internal accountId;

    mapping(address => uint256) internal keys;

    function setUp() public payable {
        (alice, alicePk) = makeAddrAndKey("alice");
        keys[alice] = alicePk;
        (bob, bobPk) = makeAddrAndKey("bob");
        keys[bob] = bobPk;
        (chuck, chuckPk) = makeAddrAndKey("chuck");
        keys[chuck] = chuckPk;
        (dave, davePk) = makeAddrAndKey("dave");
        keys[dave] = davePk;

        account = new NaniAccount();
        account.initialize(alice);
        owners = new Owners();

        accountId = uint256(keccak256(abi.encodePacked(address(account))));

        erc20 = address(new MockERC20("TEST", "TEST", 18));
        MockERC20(erc20).mint(alice, 40 ether);
        MockERC20(erc20).mint(bob, 20 ether);
        MockERC20(erc20).mint(chuck, 20 ether);
        MockERC20(erc20).mint(dave, 20 ether);

        erc721 = address(new MockERC721TotalSupply());
        MockERC721TotalSupply(erc721).mint(alice, 0);
        MockERC721TotalSupply(erc721).mint(bob, 1);
        MockERC721TotalSupply(erc721).mint(chuck, 2);
        MockERC721TotalSupply(erc721).mint(dave, 3);

        erc1155 = address(new MockERC1155TotalSupply());
        MockERC1155TotalSupply(erc1155).mint(alice, accountId, 40 ether, "");
        MockERC1155TotalSupply(erc1155).mint(bob, accountId, 20 ether, "");
        MockERC1155TotalSupply(erc1155).mint(chuck, accountId, 20 ether, "");
        MockERC1155TotalSupply(erc1155).mint(dave, accountId, 20 ether, "");

        erc6909 = address(new MockERC6909TotalSupply());
        MockERC6909TotalSupply(erc6909).mint(alice, accountId, 40 ether);
        MockERC6909TotalSupply(erc6909).mint(bob, accountId, 20 ether);
        MockERC6909TotalSupply(erc6909).mint(chuck, accountId, 20 ether);
        MockERC6909TotalSupply(erc6909).mint(dave, accountId, 20 ether);
    }

    function testDeploy() public {
        owners = new Owners();
    }

    function testInstall() public {
        address[] memory _owners = new address[](1);
        uint256[] memory _shares = new uint256[](1);
        _owners[0] = alice;
        _shares[0] = 1;

        ITokenOwner tkn = ITokenOwner(address(0));
        Owners.TokenStandard std = Owners.TokenStandard.OWN;

        uint88 threshold = 1;
        string memory uri = "";
        ITokenAuth auth = ITokenAuth(address(0));

        vm.prank(alice);
        account.execute(
            address(owners),
            0,
            abi.encodeWithSelector(
                owners.install.selector, _owners, _shares, tkn, std, threshold, uri, auth
            )
        );

        assertEq(account.ownershipHandoverExpiresAt(address(owners)), block.timestamp + 2 days);

        assertEq(owners.balanceOf(alice, accountId), 1);

        (ITokenOwner setTkn, uint88 setThreshold, Owners.TokenStandard setStd) =
            owners.settings(address(account));

        assertEq(address(setTkn), address(tkn));
        assertEq(uint256(setThreshold), uint256(threshold));
        assertEq(uint8(setStd), uint8(std));

        assertEq(owners.tokenURI(accountId), "");
        assertEq(address(owners.auths(accountId)), address(0));
    }

    function testSetThreshold() public {
        testInstall();
        vm.prank(address(account));
        owners.setThreshold(1);
        (, uint88 setThreshold,) = owners.settings(address(account));
        assertEq(setThreshold, 1);
    }

    function testFailInvalidThresholdNull() public {
        testInstall();
        vm.prank(address(account));
        owners.setThreshold(0);
    }

    function testFailInvalidThresholdExceedsSupply() public {
        testInstall();
        vm.prank(address(account));
        owners.setThreshold(2);
    }

    function testSetURI() public {
        testInstall();
        vm.prank(address(account));
        owners.setURI("TEST");
        assertEq(owners.tokenURI(accountId), "TEST");
    }

    function testSetToken(ITokenOwner tkn) public {
        Owners.TokenStandard std = Owners.TokenStandard.OWN; /*|| std == Owners.TokenStandard.ERC20
                || std == Owners.TokenStandard.ERC721 || std == Owners.TokenStandard.ERC1155
                || std == Owners.TokenStandard.ERC6909
        );*/
        testInstall();
        vm.prank(address(account));
        owners.setToken(tkn, std);
        (ITokenOwner setTkn,, Owners.TokenStandard setStd) = owners.settings(address(account));
        assertEq(address(tkn), address(setTkn));
        assertEq(uint8(std), uint8(setStd));
        std = Owners.TokenStandard.ERC20;
        vm.prank(address(account));
        owners.setToken(tkn, std);
        (setTkn,, setStd) = owners.settings(address(account));
        assertEq(address(tkn), address(setTkn));
    }

    function testSetAuth(ITokenAuth auth) public {
        testInstall();
        vm.prank(address(account));
        owners.setAuth(auth);
        assertEq(
            address(auth),
            address(owners.auths(uint256(keccak256(abi.encodePacked(address(account))))))
        );
    }

    function testIsValidSignature() public {
        address[] memory _owners = new address[](1);
        uint256[] memory _shares = new uint256[](1);
        _owners[0] = alice;
        _shares[0] = 1;

        ITokenOwner tkn = ITokenOwner(address(0));
        Owners.TokenStandard std = Owners.TokenStandard.OWN;

        uint88 threshold = 1;
        string memory uri = "";
        ITokenAuth auth = ITokenAuth(address(0));

        vm.prank(alice);
        account.execute(
            address(owners),
            0,
            abi.encodeWithSelector(
                owners.install.selector, _owners, _shares, tkn, std, threshold, uri, auth
            )
        );

        vm.prank(alice);
        account.execute(
            address(account),
            0,
            abi.encodeWithSelector(account.completeOwnershipHandover.selector, address(owners))
        );

        bytes32 userOpHash = keccak256("OWN");
        NaniAccount.UserOperation memory userOp;
        userOp.signature =
            abi.encodePacked(alice, _sign(alicePk, _toEthSignedMessageHash(userOpHash)));
        require(userOp.signature.length == 85, "INVALID_LEN");
        userOp.sender = address(account);

        vm.prank(entryPoint);
        uint256 validationData = account.validateUserOp(userOp, userOpHash, 0);
        assertEq(validationData, 0x00);
    }

    // In 2-of-3, 3 signed.
    function testIsValidSignature3of3() public payable {
        address[] memory _owners = new address[](3);
        uint256[] memory _shares = new uint256[](3);
        _owners[0] = alice;
        _shares[0] = 1;
        _owners[1] = bob;
        _shares[1] = 1;
        _owners[2] = chuck;
        _shares[2] = 1;

        vm.prank(alice);
        account.execute(
            address(owners),
            0,
            abi.encodeWithSelector(
                owners.install.selector,
                _owners,
                _shares,
                ITokenOwner(address(0)),
                Owners.TokenStandard.OWN,
                2,
                "",
                ITokenAuth(address(0))
            )
        );

        vm.prank(alice);
        account.execute(
            address(account),
            0,
            abi.encodeWithSelector(account.completeOwnershipHandover.selector, address(owners))
        );

        NaniAccount.UserOperation memory userOp;
        bytes32 userOpHash = keccak256("OWN");
        bytes32 signHash = _toEthSignedMessageHash(userOpHash);
        _owners = _sortAddresses(_owners);
        userOp.signature = abi.encodePacked(
            _owners[0],
            _sign(_getPkByAddr(_owners[0]), signHash),
            _owners[1],
            _sign(_getPkByAddr(_owners[1]), signHash),
            _owners[2],
            _sign(_getPkByAddr(_owners[2]), signHash)
        );

        vm.prank(entryPoint);
        uint256 validationData = account.validateUserOp(userOp, userOpHash, 0);
        assertEq(validationData, 0x00);
    }

    // In 2-of-3, 2 signed.
    function testIsValidSignature2of3() public payable {
        address[] memory _owners = new address[](2);
        uint256[] memory _shares = new uint256[](2);
        _owners[0] = alice;
        _shares[0] = 1;
        _owners[1] = bob;
        _shares[1] = 1;

        vm.prank(alice);
        account.execute(
            address(owners),
            0,
            abi.encodeWithSelector(
                owners.install.selector,
                _owners,
                _shares,
                ITokenOwner(address(0)),
                Owners.TokenStandard.OWN,
                2,
                "",
                ITokenAuth(address(0))
            )
        );

        vm.prank(alice);
        account.execute(
            address(account),
            0,
            abi.encodeWithSelector(account.completeOwnershipHandover.selector, address(owners))
        );

        NaniAccount.UserOperation memory userOp;
        bytes32 userOpHash = keccak256("OWN");
        bytes32 signHash = _toEthSignedMessageHash(userOpHash);
        _owners = _sortAddresses(_owners);
        userOp.signature = abi.encodePacked(
            _owners[0],
            _sign(_getPkByAddr(_owners[0]), signHash),
            _owners[1],
            _sign(_getPkByAddr(_owners[1]), signHash)
        );

        vm.prank(entryPoint);
        uint256 validationData = account.validateUserOp(userOp, userOpHash, 0);
        assertEq(validationData, 0x00);
    }

    // In 2-of-3, 1 signed. So fail.
    function testFailIsValidSignature2of3ForInsufficientSignatures() public payable {
        address[] memory _owners = new address[](2);
        uint256[] memory _shares = new uint256[](2);
        _owners[0] = alice;
        _shares[0] = 1;
        _owners[1] = bob;
        _shares[1] = 1;

        vm.prank(alice);
        account.execute(
            address(owners),
            0,
            abi.encodeWithSelector(
                owners.install.selector,
                _owners,
                _shares,
                ITokenOwner(address(0)),
                Owners.TokenStandard.OWN,
                2,
                "",
                ITokenAuth(address(0))
            )
        );

        vm.prank(alice);
        account.execute(
            address(account),
            0,
            abi.encodeWithSelector(account.completeOwnershipHandover.selector, address(owners))
        );

        NaniAccount.UserOperation memory userOp;
        bytes32 userOpHash = keccak256("OWN");
        bytes32 signHash = _toEthSignedMessageHash(userOpHash);
        _owners = _sortAddresses(_owners);
        userOp.signature = abi.encodePacked(_owners[0], _sign(_getPkByAddr(_owners[0]), signHash));

        vm.prank(entryPoint);
        uint256 validationData = account.validateUserOp(userOp, userOpHash, 0);
        assertEq(validationData, 0x00);
    }

    // In 40-of-100, at least 40 units signed.
    function testIsValidSignatureWeighted() public payable {
        address[] memory _owners = new address[](4);
        uint256[] memory _shares = new uint256[](4);
        _owners[0] = alice;
        _shares[0] = 40;
        _owners[1] = bob;
        _shares[1] = 20;
        _owners[2] = chuck;
        _shares[2] = 20;
        _owners[3] = dave;
        _shares[3] = 20;

        vm.prank(alice);
        account.execute(
            address(owners),
            0,
            abi.encodeWithSelector(
                owners.install.selector,
                _owners,
                _shares,
                ITokenOwner(address(0)),
                Owners.TokenStandard.OWN,
                40,
                "",
                ITokenAuth(address(0))
            )
        );

        vm.prank(alice);
        account.execute(
            address(account),
            0,
            abi.encodeWithSelector(account.completeOwnershipHandover.selector, address(owners))
        );

        NaniAccount.UserOperation memory userOp;
        bytes32 userOpHash = keccak256("OWN");
        bytes32 signHash = _toEthSignedMessageHash(userOpHash);
        _owners = _sortAddresses(_owners);
        userOp.signature = abi.encodePacked(
            _owners[0],
            _sign(_getPkByAddr(_owners[0]), signHash),
            _owners[1],
            _sign(_getPkByAddr(_owners[1]), signHash),
            _owners[2],
            _sign(_getPkByAddr(_owners[2]), signHash)
        );

        vm.prank(entryPoint);
        uint256 validationData = account.validateUserOp(userOp, userOpHash, 0);
        assertEq(validationData, 0x00);
    }

    // In 40-of-100, 20 units signed. So fail.
    function testFailIsValidSignatureWeighted() public payable {
        address[] memory _owners = new address[](4);
        uint256[] memory _shares = new uint256[](4);
        _owners[0] = alice;
        _shares[0] = 40;
        _owners[1] = bob;
        _shares[1] = 20;
        _owners[2] = chuck;
        _shares[2] = 20;
        _owners[3] = dave;
        _shares[3] = 20;

        vm.prank(alice);
        account.execute(
            address(owners),
            0,
            abi.encodeWithSelector(
                owners.install.selector,
                _owners,
                _shares,
                ITokenOwner(address(0)),
                Owners.TokenStandard.OWN,
                40,
                "",
                ITokenAuth(address(0))
            )
        );

        vm.prank(alice);
        account.execute(
            address(account),
            0,
            abi.encodeWithSelector(account.completeOwnershipHandover.selector, address(owners))
        );

        NaniAccount.UserOperation memory userOp;
        bytes32 userOpHash = keccak256("OWN");
        bytes32 signHash = _toEthSignedMessageHash(userOpHash);
        _owners = _sortAddresses(_owners);
        userOp.signature = abi.encodePacked(_owners[0], _sign(_getPkByAddr(_owners[0]), signHash));

        vm.prank(entryPoint);
        uint256 validationData = account.validateUserOp(userOp, userOpHash, 0);
        assertEq(validationData, 0x00);
    }

    // In 40-of-100, at least 40 ERC20 units signed.
    function testIsValidSignatureWeightedERC20() public payable {
        address[] memory _owners = new address[](0);
        uint256[] memory _shares = new uint256[](0);

        address[] memory memOwners = new address[](3);
        memOwners[0] = alice;
        memOwners[1] = bob;
        memOwners[2] = chuck;

        vm.prank(alice);
        account.execute(
            address(owners),
            0,
            abi.encodeWithSelector(
                owners.install.selector,
                _owners,
                _shares,
                ITokenOwner(erc20),
                Owners.TokenStandard.ERC20,
                40 ether,
                "",
                ITokenAuth(address(0))
            )
        );

        vm.prank(alice);
        account.execute(
            address(account),
            0,
            abi.encodeWithSelector(account.completeOwnershipHandover.selector, address(owners))
        );

        NaniAccount.UserOperation memory userOp;
        bytes32 userOpHash = keccak256("OWN");
        bytes32 signHash = _toEthSignedMessageHash(userOpHash);
        _owners = _sortAddresses(memOwners);
        userOp.signature = abi.encodePacked(
            _owners[0],
            _sign(_getPkByAddr(_owners[0]), signHash),
            _owners[1],
            _sign(_getPkByAddr(_owners[1]), signHash),
            _owners[2],
            _sign(_getPkByAddr(_owners[2]), signHash)
        );

        vm.prank(entryPoint);
        uint256 validationData = account.validateUserOp(userOp, userOpHash, 0);
        assertEq(validationData, 0x00);
    }

    // In 40-of-100, 20 units signed. So fail.
    function testFailIsValidSignatureWeightedERC20() public payable {
        address[] memory _owners = new address[](0);
        uint256[] memory _shares = new uint256[](0);

        address[] memory memOwners = new address[](3);
        memOwners[0] = alice;
        memOwners[1] = bob;
        memOwners[2] = chuck;

        vm.prank(alice);
        account.execute(
            address(owners),
            0,
            abi.encodeWithSelector(
                owners.install.selector,
                _owners,
                _shares,
                ITokenOwner(erc20),
                Owners.TokenStandard.ERC20,
                40 ether,
                "",
                ITokenAuth(address(0))
            )
        );

        vm.prank(alice);
        account.execute(
            address(account),
            0,
            abi.encodeWithSelector(account.completeOwnershipHandover.selector, address(owners))
        );

        NaniAccount.UserOperation memory userOp;
        bytes32 userOpHash = keccak256("OWN");
        bytes32 signHash = _toEthSignedMessageHash(userOpHash);
        _owners = _sortAddresses(memOwners);
        userOp.signature = abi.encodePacked(_owners[0], _sign(_getPkByAddr(_owners[0]), signHash));

        vm.prank(entryPoint);
        uint256 validationData = account.validateUserOp(userOp, userOpHash, 0);
        assertEq(validationData, 0x00);
    }

    // In 2-of-3, at least 2 ERC721 units signed.
    function testIsValidSignatureWeightedERC721() public payable {
        address[] memory _owners = new address[](0);
        uint256[] memory _shares = new uint256[](0);

        address[] memory memOwners = new address[](3);
        memOwners[0] = alice;
        memOwners[1] = bob;
        memOwners[2] = chuck;

        vm.prank(alice);
        account.execute(
            address(owners),
            0,
            abi.encodeWithSelector(
                owners.install.selector,
                _owners,
                _shares,
                ITokenOwner(erc721),
                Owners.TokenStandard.ERC721,
                2,
                "",
                ITokenAuth(address(0))
            )
        );

        vm.prank(alice);
        account.execute(
            address(account),
            0,
            abi.encodeWithSelector(account.completeOwnershipHandover.selector, address(owners))
        );

        NaniAccount.UserOperation memory userOp;
        bytes32 userOpHash = keccak256("OWN");
        bytes32 signHash = _toEthSignedMessageHash(userOpHash);
        _owners = _sortAddresses(memOwners);
        userOp.signature = abi.encodePacked(
            _owners[0],
            _sign(_getPkByAddr(_owners[0]), signHash),
            _owners[1],
            _sign(_getPkByAddr(_owners[1]), signHash)
        );

        vm.prank(entryPoint);
        uint256 validationData = account.validateUserOp(userOp, userOpHash, 0);
        assertEq(validationData, 0x00);
    }

    // In 2-of-3, only 1 ERC721 units signed. So fail.
    function testFailIsValidSignatureWeightedERC721() public payable {
        address[] memory _owners = new address[](0);
        uint256[] memory _shares = new uint256[](0);

        address[] memory memOwners = new address[](3);
        memOwners[0] = alice;
        memOwners[1] = bob;
        memOwners[2] = chuck;

        vm.prank(alice);
        account.execute(
            address(owners),
            0,
            abi.encodeWithSelector(
                owners.install.selector,
                _owners,
                _shares,
                ITokenOwner(erc721),
                Owners.TokenStandard.ERC721,
                2,
                "",
                ITokenAuth(address(0))
            )
        );

        vm.prank(alice);
        account.execute(
            address(account),
            0,
            abi.encodeWithSelector(account.completeOwnershipHandover.selector, address(owners))
        );

        NaniAccount.UserOperation memory userOp;
        bytes32 userOpHash = keccak256("OWN");
        bytes32 signHash = _toEthSignedMessageHash(userOpHash);
        _owners = _sortAddresses(memOwners);
        userOp.signature = abi.encodePacked(_owners[0], _sign(_getPkByAddr(_owners[0]), signHash));

        vm.prank(entryPoint);
        uint256 validationData = account.validateUserOp(userOp, userOpHash, 0);
        assertEq(validationData, 0x00);
    }

    // In 40-of-100, at least 40 ERC1155 units signed.
    function testIsValidSignatureWeightedERC1155() public payable {
        address[] memory _owners = new address[](0);
        uint256[] memory _shares = new uint256[](0);

        address[] memory memOwners = new address[](3);
        memOwners[0] = alice;
        memOwners[1] = bob;
        memOwners[2] = chuck;

        vm.prank(alice);
        account.execute(
            address(owners),
            0,
            abi.encodeWithSelector(
                owners.install.selector,
                _owners,
                _shares,
                ITokenOwner(erc1155),
                Owners.TokenStandard.ERC1155,
                40 ether,
                "",
                ITokenAuth(address(0))
            )
        );

        vm.prank(alice);
        account.execute(
            address(account),
            0,
            abi.encodeWithSelector(account.completeOwnershipHandover.selector, address(owners))
        );

        NaniAccount.UserOperation memory userOp;
        bytes32 userOpHash = keccak256("OWN");
        bytes32 signHash = _toEthSignedMessageHash(userOpHash);
        _owners = _sortAddresses(memOwners);
        userOp.signature = abi.encodePacked(
            _owners[0],
            _sign(_getPkByAddr(_owners[0]), signHash),
            _owners[1],
            _sign(_getPkByAddr(_owners[1]), signHash),
            _owners[2],
            _sign(_getPkByAddr(_owners[2]), signHash)
        );

        vm.prank(entryPoint);
        uint256 validationData = account.validateUserOp(userOp, userOpHash, 0);
        assertEq(validationData, 0x00);
    }

    // In 40-of-100, 20 ERC1155 units signed. So fail.
    function testFailIsValidSignatureWeightedERC1155() public payable {
        address[] memory _owners = new address[](0);
        uint256[] memory _shares = new uint256[](0);

        address[] memory memOwners = new address[](3);
        memOwners[0] = alice;
        memOwners[1] = bob;
        memOwners[2] = chuck;

        vm.prank(alice);
        account.execute(
            address(owners),
            0,
            abi.encodeWithSelector(
                owners.install.selector,
                _owners,
                _shares,
                ITokenOwner(erc1155),
                Owners.TokenStandard.ERC1155,
                40 ether,
                "",
                ITokenAuth(address(0))
            )
        );

        vm.prank(alice);
        account.execute(
            address(account),
            0,
            abi.encodeWithSelector(account.completeOwnershipHandover.selector, address(owners))
        );

        NaniAccount.UserOperation memory userOp;
        bytes32 userOpHash = keccak256("OWN");
        bytes32 signHash = _toEthSignedMessageHash(userOpHash);
        _owners = _sortAddresses(memOwners);
        userOp.signature = abi.encodePacked(_owners[0], _sign(_getPkByAddr(_owners[0]), signHash));

        vm.prank(entryPoint);
        uint256 validationData = account.validateUserOp(userOp, userOpHash, 0);
        assertEq(validationData, 0x00);
    }

    // In 40-of-100, at least 40 ERC6909 units signed.
    function testIsValidSignatureWeightedERC6909() public payable {
        address[] memory _owners = new address[](0);
        uint256[] memory _shares = new uint256[](0);

        address[] memory memOwners = new address[](3);
        memOwners[0] = alice;
        memOwners[1] = bob;
        memOwners[2] = chuck;

        vm.prank(alice);
        account.execute(
            address(owners),
            0,
            abi.encodeWithSelector(
                owners.install.selector,
                _owners,
                _shares,
                ITokenOwner(erc6909),
                Owners.TokenStandard.ERC6909,
                40 ether,
                "",
                ITokenAuth(address(0))
            )
        );

        vm.prank(alice);
        account.execute(
            address(account),
            0,
            abi.encodeWithSelector(account.completeOwnershipHandover.selector, address(owners))
        );

        NaniAccount.UserOperation memory userOp;
        bytes32 userOpHash = keccak256("OWN");
        bytes32 signHash = _toEthSignedMessageHash(userOpHash);
        _owners = _sortAddresses(memOwners);
        userOp.signature = abi.encodePacked(
            _owners[0],
            _sign(_getPkByAddr(_owners[0]), signHash),
            _owners[1],
            _sign(_getPkByAddr(_owners[1]), signHash),
            _owners[2],
            _sign(_getPkByAddr(_owners[2]), signHash)
        );

        vm.prank(entryPoint);
        uint256 validationData = account.validateUserOp(userOp, userOpHash, 0);
        assertEq(validationData, 0x00);
    }

    // In 40-of-100, 20 ERC6909 units signed. So fail.
    function testFailIsValidSignatureWeightedERC6909() public payable {
        address[] memory _owners = new address[](0);
        uint256[] memory _shares = new uint256[](0);

        address[] memory memOwners = new address[](3);
        memOwners[0] = alice;
        memOwners[1] = bob;
        memOwners[2] = chuck;

        vm.prank(alice);
        account.execute(
            address(owners),
            0,
            abi.encodeWithSelector(
                owners.install.selector,
                _owners,
                _shares,
                ITokenOwner(erc6909),
                Owners.TokenStandard.ERC6909,
                40 ether,
                "",
                ITokenAuth(address(0))
            )
        );

        vm.prank(alice);
        account.execute(
            address(account),
            0,
            abi.encodeWithSelector(account.completeOwnershipHandover.selector, address(owners))
        );

        NaniAccount.UserOperation memory userOp;
        bytes32 userOpHash = keccak256("OWN");
        bytes32 signHash = _toEthSignedMessageHash(userOpHash);
        _owners = _sortAddresses(memOwners);
        userOp.signature = abi.encodePacked(_owners[0], _sign(_getPkByAddr(_owners[0]), signHash));

        vm.prank(entryPoint);
        uint256 validationData = account.validateUserOp(userOp, userOpHash, 0);
        assertEq(validationData, 0x00);
    }

    function testFailIsValidSignatureOutOfOrder() public payable {
        address[] memory _owners = new address[](4);
        uint256[] memory _shares = new uint256[](4);
        _owners[0] = alice;
        _shares[0] = 40;
        _owners[1] = bob;
        _shares[1] = 20;
        _owners[2] = chuck;
        _shares[2] = 20;
        _owners[3] = dave;
        _shares[3] = 20;

        vm.prank(alice);
        account.execute(
            address(owners),
            0,
            abi.encodeWithSelector(
                owners.install.selector,
                _owners,
                _shares,
                ITokenOwner(address(0)),
                Owners.TokenStandard.OWN,
                40,
                "",
                ITokenAuth(address(0))
            )
        );

        vm.prank(alice);
        account.execute(
            address(account),
            0,
            abi.encodeWithSelector(account.completeOwnershipHandover.selector, address(owners))
        );

        NaniAccount.UserOperation memory userOp;
        bytes32 userOpHash = keccak256("OWN");
        bytes32 signHash = _toEthSignedMessageHash(userOpHash);
        userOp.signature = abi.encodePacked(
            _owners[0],
            _sign(_getPkByAddr(_owners[0]), signHash),
            _owners[1],
            _sign(_getPkByAddr(_owners[1]), signHash),
            _owners[2],
            _sign(_getPkByAddr(_owners[2]), signHash)
        );

        vm.prank(entryPoint);
        uint256 validationData = account.validateUserOp(userOp, userOpHash, 0);
        assertEq(validationData, 0x00);
    }

    function testFailIsValidSignatureInvalidTokenCode() public payable {
        address[] memory _owners = new address[](4);
        uint256[] memory _shares = new uint256[](4);
        _owners[0] = alice;
        _shares[0] = 40;
        _owners[1] = bob;
        _shares[1] = 20;
        _owners[2] = chuck;
        _shares[2] = 20;
        _owners[3] = dave;
        _shares[3] = 20;

        vm.prank(alice);
        account.execute(
            address(owners),
            0,
            abi.encodeWithSelector(
                owners.install.selector,
                _owners,
                _shares,
                ITokenOwner(address(0)),
                9, // Bad Code.
                40,
                "",
                ITokenAuth(address(0))
            )
        );

        vm.prank(alice);
        account.execute(
            address(account),
            0,
            abi.encodeWithSelector(account.completeOwnershipHandover.selector, address(owners))
        );

        NaniAccount.UserOperation memory userOp;
        bytes32 userOpHash = keccak256("OWN");
        bytes32 signHash = _toEthSignedMessageHash(userOpHash);
        _owners = _sortAddresses(_owners);
        userOp.signature = abi.encodePacked(
            _owners[0],
            _sign(_getPkByAddr(_owners[0]), signHash),
            _owners[1],
            _sign(_getPkByAddr(_owners[1]), signHash),
            _owners[2],
            _sign(_getPkByAddr(_owners[2]), signHash)
        );

        vm.prank(entryPoint);
        uint256 validationData = account.validateUserOp(userOp, userOpHash, 0);
        assertEq(validationData, 0x00);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////////////////

    function _toEthSignedMessageHash(bytes32 hash) internal pure returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x20, hash) // Store into scratch space for keccak256.
            mstore(0x00, "\x00\x00\x00\x00\x19Ethereum Signed Message:\n32") // 28 bytes.
            result := keccak256(0x04, 0x3c) // `32 * 2 - (32 - 28) = 60 = 0x3c`.
        }
    }

    function _getPkByAddr(address user) internal view returns (uint256) {
        return keys[user];
    }

    function _sign(uint256 pK, bytes32 hash) internal pure returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pK, hash);
        return abi.encodePacked(r, s, v);
    }

    function _sortAddresses(address[] memory addresses) internal pure returns (address[] memory) {
        for (uint256 i = 0; i < addresses.length; i++) {
            for (uint256 j = i + 1; j < addresses.length; j++) {
                if (uint160(addresses[i]) > uint160(addresses[j])) {
                    address temp = addresses[i];
                    addresses[i] = addresses[j];
                    addresses[j] = temp;
                }
            }
        }
        return addresses;
    }
}