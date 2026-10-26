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
    using MessageHashUtils for bytes32;
    




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
        return  _validateSignatures(userOpHash , userOp.signature);
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
        for(uint256 i = 0 ; i < required ; i++){

        }


        return 0;
    }

}