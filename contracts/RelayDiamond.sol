// SPDX-License-Identifier: MIT
pragma solidity ^0.7.1;
pragma experimental ABIEncoderV2;

/******************************************************************************\
* Author: Nick Mudge <nick@perfectabstractions.com> (https://twitter.com/mudgen)
* EIP-2535 Diamond Standard: https://eips.ethereum.org/EIPS/eip-2535
*
* Implementation of a diamond.
/******************************************************************************/

import 'diamond-2/contracts/libraries/LibDiamond.sol';
import 'diamond-2/contracts/interfaces/IDiamondLoupe.sol';
import 'diamond-2/contracts/interfaces/IDiamondCut.sol';
import 'diamond-2/contracts/interfaces/IERC173.sol';
import 'diamond-2/contracts/interfaces/IERC165.sol';

contract RelayDiamond {
    constructor(IDiamondCut.FacetCut[] memory _diamondCut, address _owner) payable {
        LibDiamond.diamondCut(_diamondCut, address(0), new bytes(0));
        LibDiamond.setContractOwner(_owner);

        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();

        // adding ERC165 data
        ds.supportedInterfaces[type(IERC165).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondCut).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondLoupe).interfaceId] = true;
        ds.supportedInterfaces[type(IERC173).interfaceId] = true;
    }

    // Find facet for function that is called and execute the
    // function if a facet is found and return any value.
    fallback() external payable {
        LibDiamond.DiamondStorage storage ds;
        bytes32 position = LibDiamond.DIAMOND_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
        address facet = address(bytes20(ds.facets[msg.sig]));

        require(facet != address(0), 'Diamond: Function does not exist');
        assembly {
            calldatacopy(0, 0, calldatasize())
            if eq(caller(), address()) {
                let result := delegatecall(gas(), facet, 0, calldatasize(), 0, 0)
                returndatacopy(0, 0, returndatasize())
                switch result
                    case 0 {
                        revert(0, returndatasize())
                    }
                    default {
                        return(0, returndatasize())
                    }
            }
            {
                mstore(calldatasize(), caller())
                let result := delegatecall(gas(), facet, 0, add(calldatasize(), 0x20), 0, 0)
                returndatacopy(0, 0, returndatasize())
                switch result
                    case 0 {
                        revert(0, returndatasize())
                    }
                    default {
                        return(0, returndatasize())
                    }
            }
        }
    }

    receive() external payable {}
}
