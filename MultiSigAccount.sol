// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;


import "https://github.com/eth-infinitism/account-abstraction/blob/v0.7.0/contracts/interfaces/IAccount.sol";
import "https://github.com/eth-infinitism/account-abstraction/blob/v0.7.0/contracts/interfaces/IEntryPoint.sol";
import "https://github.com/eth-infinitism/account-abstraction/blob/v0.7.0/contracts/interfaces/PackedUserOperation.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";



contract MultiSigAccount is IAccount{
    IEntryPoint public immutable entryPoint;
    address[] public owners;
    mapping(address => bool) public isOwner;
    uint256 public required;
    event Deposit(address indexed sender, uint256 amount, uint256 balance);
    error NotEntryPoint();
    error NotExecuter();
    error CallFailed();
    error LengthMismatch();
    error NotSelf();
    error InvalidOwner();
    error InvalidRequired();
    using MessageHashUtils for bytes32;
    event OwnerAdded(address indexed _newOwner);
    event OwnerRemoved(address indexed _removedOwner);
    event RequirementChanged(uint256 _required);


    constructor(IEntryPoint _entryPoint, address[] memory _owners, uint256 _required){
        require(_owners.length > 0 , "no Owners");
        require(_required > 0 && _required <= _owners.length,"check the required Owners number");
        for(uint256 i =0 ; i < _owners.length ; i++){
            address owner = _owners[i];
            require(owner != address(0),"check your address");
            require(!isOwner[owner] ,"owner already exists");
            isOwner[owner] = true;
            owners.push(owner);
        }
        required = _required;
        entryPoint = _entryPoint;
    }
    function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    ) external override onlyEntryPoint returns (uint256 validationData) {  
        uint256 check = _validateSignatures(userOpHash , userOp.signature);
        _payPrefund(missingAccountFunds);
        return check;

    }
    receive() external  payable {
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }
    modifier onlyEntryPoint{
        if(address(entryPoint) != msg.sender) revert NotEntryPoint();
        _;
    }


    function _validateSignatures(bytes32 userOpHash , bytes calldata signature) internal view returns(uint256){
        if(signature.length != required * 65){
            return 1;
        }
        bytes32 digest = userOpHash.toEthSignedMessageHash();
        address lastSigner = address(0);

        for(uint256 i = 0 ; i < required ; i++){
            (address signer,ECDSA.RecoverError err,) = ECDSA.tryRecover(digest,signature[i* 65 : ( i + 1 ) * 65]);
            if(err != ECDSA.RecoverError.NoError || !isOwner[signer] || signer <= lastSigner){
                return 1;
            }
            lastSigner = signer;
        }
        return 0;
    }
    function _payPrefund(uint256 amount) internal {
        if(amount != 0){
            (bool callSuccess, ) = payable (msg.sender).call{value : amount}("");
            require(callSuccess , "Call Failed");
        }    
    }
    modifier  onlyEntryPointOrSelf{
        if(address(entryPoint) != msg.sender && msg.sender != address(this)) revert NotExecuter();
        _;
    }
    function execute(address to, uint256 value, bytes calldata data) external onlyEntryPointOrSelf{
        (bool callsuccess, ) = payable (to).call{value : value}(data);
        if(!callsuccess) revert CallFailed();
    }
    function executeBatch(address[] calldata to , uint256[] calldata values , bytes[] calldata datas) external onlyEntryPointOrSelf{
        if(to.length != values.length || to.length != datas.length || datas.length != values.length) revert LengthMismatch();
        for(uint256 i = 0 ; i < to.length ; i++){
            (bool callSuccess, ) = payable(to[i]).call{value : values[i]}(datas[i]);
            if(!callSuccess) revert CallFailed();
        }
    }
    modifier onlySelf{
        if(msg.sender != address(this)) revert NotSelf();
        _;
    }

    function addOwner(address _newOwner) external onlySelf{
        if(_newOwner == address(0) || isOwner[_newOwner]) revert InvalidOwner();
        isOwner[_newOwner] = true;
        owners.push(_newOwner);
        emit OwnerAdded(_newOwner);
    }
    function removeOwner(address _owner) external onlySelf {
        if (!isOwner[_owner]) revert InvalidOwner();
        if (owners.length - 1 < required) revert InvalidRequired();

        isOwner[_owner] = false;

        for (uint256 i = 0; i < owners.length; i++) {
            if (owners[i] == _owner) {
                owners[i] = owners[owners.length - 1];
                owners.pop();
                break;
            }
        }

        emit OwnerRemoved(_owner);
    }

    function changeRequirement(uint256 _required) external onlySelf{
        if(_required == 0 || _required > owners.length) revert InvalidRequired();
        required = _required;
        emit RequirementChanged(_required);
    }
    function getOwners() external view returns (address[] memory) {
        return owners;
    }

    function getNonce() external view returns (uint256) {
        return entryPoint.getNonce(address(this), 0);
    }

    function addDeposit() external payable {
        entryPoint.depositTo{value: msg.value}(address(this));
    }

    function getDeposit() external view returns (uint256) {
        return entryPoint.balanceOf(address(this));
    }

}