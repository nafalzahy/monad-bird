// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

/// @title Monad Bird - game burung dengan boss dan NFT trophy on-chain
contract MonadBird is ERC721 {
    using Strings for uint256;

    address public immutable signer;
    uint8 public constant MAX_BOSS = 4;

    mapping(address => uint8) public highestDefeated;
    mapping(address => uint256) public bestScore;
    mapping(address => mapping(uint8 => uint256)) public trophyOf; // pemain => boss => tokenId
    mapping(uint256 => uint8) public trophyBoss;
    mapping(uint256 => uint256) public trophyScore;
    mapping(address => bool) private registered;
    address[] private players;
    uint256 private nextId = 1;

    event BossDefeated(address indexed player, uint8 bossId, uint256 score, uint256 tokenId);

    constructor(address _signer) ERC721("Monad Bird Trophy", "MBT") {
        signer = _signer;
    }

    /// Klaim kemenangan. Tanda tangan dibuat server setelah memutar ulang permainan.
    function claim(uint8 bossId, uint256 score, bytes calldata sig) external {
        require(bossId >= 1 && bossId <= MAX_BOSS, "Boss tidak ada");
        require(bossId <= highestDefeated[msg.sender] + 1, "Kalahkan boss sebelumnya dulu");

        bytes32 h = keccak256(abi.encodePacked(address(this), block.chainid, msg.sender, bossId, score));
        address rec = ECDSA.recover(MessageHashUtils.toEthSignedMessageHash(h), sig);
        require(rec == signer, "Tanda tangan tidak valid");

        if (!registered[msg.sender]) {
            registered[msg.sender] = true;
            players.push(msg.sender);
        }
        if (bossId > highestDefeated[msg.sender]) highestDefeated[msg.sender] = bossId;
        if (score > bestScore[msg.sender]) bestScore[msg.sender] = score;

        uint256 tokenId = trophyOf[msg.sender][bossId];
        if (tokenId == 0) {
            tokenId = nextId++;
            trophyOf[msg.sender][bossId] = tokenId;
            trophyBoss[tokenId] = bossId;
            trophyScore[tokenId] = score;
            _mint(msg.sender, tokenId);
        }
        emit BossDefeated(msg.sender, bossId, score, tokenId);
    }

    function getLeaderboard() external view returns (address[5] memory addrs, uint256[5] memory scores) {
        for (uint256 i = 0; i < players.length; i++) {
            address p = players[i];
            uint256 s = bestScore[p];
            for (uint256 j = 0; j < 5; j++) {
                if (s > scores[j]) {
                    for (uint256 k = 4; k > j; k--) {
                        scores[k] = scores[k - 1];
                        addrs[k] = addrs[k - 1];
                    }
                    scores[j] = s;
                    addrs[j] = p;
                    break;
                }
            }
        }
    }

    // ===== NFT: gambar dan metadata dibuat on-chain =====

    function bossName(uint8 id) public pure returns (string memory) {
        if (id == 1) return "Elang";
        if (id == 2) return "Naga Angin";
        if (id == 3) return "Phoenix";
        return "Raja Langit";
    }

    function rarityName(uint8 id) public pure returns (string memory) {
        if (id == 1) return "Common";
        if (id == 2) return "Rare";
        if (id == 3) return "Epic";
        return "Legendary";
    }

    function _colors(uint8 id) internal pure returns (string memory, string memory) {
        if (id == 1) return ("#d9b988", "#7a5c33");
        if (id == 2) return ("#6aa9ff", "#2b55c9");
        if (id == 3) return ("#ff8a3d", "#c9302b");
        return ("#ffd54a", "#8f5bff");
    }

    function _bg(string memory c1, string memory c2) internal pure returns (string memory) {
        return string.concat(
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 400"><defs>',
            '<linearGradient id="g" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="', c1,
            '"/><stop offset="1" stop-color="', c2,
            '"/></linearGradient><radialGradient id="s"><stop offset="0" stop-color="', c1,
            '" stop-opacity=".5"/><stop offset="1" stop-color="', c1,
            '" stop-opacity="0"/></radialGradient></defs><rect width="400" height="400" rx="28" fill="#0f0b1e"/>',
            '<circle cx="200" cy="150" r="150" fill="url(#s)"/>'
        );
    }

    function _bird(uint8 id) internal pure returns (string memory) {
        string memory crown = id == 4
            ? '<polygon points="242,112 250,84 264,104 278,84 286,112" fill="#ffd54a"/>'
            : "";
        string memory tail = id >= 3
            ? '<polygon points="120,150 40,110 70,170 40,200 125,195" fill="url(#g)"/>'
            : '<polygon points="120,175 70,150 80,205" fill="url(#g)"/>';
        return string.concat(
            tail,
            '<ellipse cx="195" cy="175" rx="78" ry="56" fill="url(#g)"/><circle cx="262" cy="140" r="36" fill="url(#g)"/>',
            '<polygon points="292,138 332,150 292,162" fill="#ffb02e"/><circle cx="272" cy="132" r="7" fill="#0f0b1e"/>',
            '<path d="M150 170 Q105 95 195 120 Q222 150 195 195Z" fill="#fff" fill-opacity=".35"/>',
            crown
        );
    }

    function _footer(uint256 tokenId, uint8 id, string memory c1) internal view returns (string memory) {
        string memory stars;
        for (uint256 i = 0; i < id; i++) {
            stars = string.concat(
                stars, '<circle cx="', (200 - (uint256(id) - 1) * 16 + i * 32).toString(),
                '" cy="262" r="8" fill="', c1, '"/>'
            );
        }
        return string.concat(
            stars,
            '<text x="200" y="306" font-size="30" font-weight="bold" text-anchor="middle" fill="#fff" font-family="Arial">',
            bossName(id),
            '</text><text x="200" y="338" font-size="20" text-anchor="middle" fill="', c1, '" font-family="Arial">',
            rarityName(id), " - Skor ", trophyScore[tokenId].toString(),
            '</text><text x="200" y="372" font-size="14" text-anchor="middle" fill="#a79bd6" font-family="Arial">Monad Bird #',
            tokenId.toString(), "</text></svg>"
        );
    }

    function _svg(uint256 tokenId, uint8 id) internal view returns (string memory) {
        (string memory c1, string memory c2) = _colors(id);
        return string.concat(_bg(c1, c2), _bird(id), _footer(tokenId, id, c1));
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireOwned(tokenId);
        uint8 id = trophyBoss[tokenId];
        string memory a = string.concat(
            '{"name":"', bossName(id), " Trophy #", tokenId.toString(),
            '","description":"Trophy on-chain dari Monad Bird. Boss: ', bossName(id), '.",'
        );
        string memory b = string.concat(
            '"attributes":[{"trait_type":"Boss","value":"', bossName(id),
            '"},{"trait_type":"Rarity","value":"', rarityName(id),
            '"},{"trait_type":"Score","value":', trophyScore[tokenId].toString(), "}],"
        );
        string memory c = string.concat(
            '"image":"data:image/svg+xml;base64,', Base64.encode(bytes(_svg(tokenId, id))), '"}'
        );
        return string.concat("data:application/json;base64,", Base64.encode(bytes(string.concat(a, b, c))));
    }
}