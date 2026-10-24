// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {MonadBird} from "../src/MonadBird.sol";

contract MonadBirdTest is Test {
    MonadBird q;
    uint256 signerPk = 0xA11CE;
    address alice = makeAddr("alice");

    function setUp() public {
        q = new MonadBird(vm.addr(signerPk));
    }

    function _sig(address p, uint8 id, uint256 score) internal view returns (bytes memory) {
        bytes32 h = keccak256(abi.encodePacked(address(q), block.chainid, p, id, score));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, MessageHashUtils.toEthSignedMessageHash(h));
        return abi.encodePacked(r, s, v);
    }

    function test_ClaimMintsTrophy() public {
        vm.prank(alice);
        q.claim(1, 700, _sig(alice, 1, 700));
        assertEq(q.balanceOf(alice), 1);
        assertEq(q.highestDefeated(alice), 1);
        assertEq(q.bestScore(alice), 700);
    }

    function test_WrongScoreReverts() public {
        bytes memory sig = _sig(alice, 1, 700);
        vm.prank(alice);
        vm.expectRevert();
        q.claim(1, 9999, sig);
    }

    function test_CannotSkipBoss() public {
        vm.prank(alice);
        vm.expectRevert();
        q.claim(2, 500, _sig(alice, 2, 500));
    }

    function test_FullRunAndReclaim() public {
        vm.startPrank(alice);
        for (uint8 i = 1; i <= 4; i++) q.claim(i, 600 + i, _sig(alice, i, 600 + i));
        assertEq(q.balanceOf(alice), 4);
        assertGt(bytes(q.tokenURI(q.trophyOf(alice, 4))).length, 0);
        q.claim(1, 900, _sig(alice, 1, 900)); // main ulang: tidak mint lagi, skor naik
        vm.stopPrank();
        assertEq(q.balanceOf(alice), 4);
        assertEq(q.bestScore(alice), 900);
    }
}