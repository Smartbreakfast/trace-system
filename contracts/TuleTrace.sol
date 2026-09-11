// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title Sổ neo dữ liệu truy xuất Tú Lệ
/// @notice Hợp đồng chỉ phát sự kiện, không lưu nội dung hồ sơ. Thứ cần bất
/// biến là mã băm và thời điểm; nội dung nằm ở D1 và R2 để còn sửa được lỗi
/// chính tả mà không phải trả tiền gas, và để không đẩy dữ liệu cá nhân lên
/// chuỗi vĩnh viễn.
///
/// Sổ vai trò (`roleOf`) tồn tại để chuẩn bị cho bước phi tập trung: khi hợp
/// tác xã tự ký lô nguyên liệu của họ, người xem cần phân biệt được chữ ký của
/// nhà cung cấp với chữ ký của thương hiệu.
contract TuleTrace {
    uint8 public constant ROLE_NONE = 0;
    uint8 public constant ROLE_SUPPLIER = 1;
    uint8 public constant ROLE_PACKAGER = 2;
    uint8 public constant ROLE_BRAND = 3;

    address public owner;
    mapping(address => uint8) public roleOf;
    mapping(address => string) public nameOf;

    event ActorSet(address indexed actor, uint8 role, string name);
    event OwnerChanged(address indexed from, address indexed to);

    /// @param hash Mã băm SHA-256 của snapshot lô nguyên liệu.
    /// @param ref Mã lô nguyên liệu, ví dụ COM-TL-2026-08.
    event IngredientAnchored(
        bytes32 indexed hash,
        address indexed by,
        string ref,
        uint64 anchoredAt
    );

    /// @param inputs Mã băm của các lô nguyên liệu tạo nên lô này. Nhờ mảng
    /// này mà lô thành phẩm trỏ ngược được về đúng những bản ghi đã neo trước
    /// đó, thay vì là một bản ghi rời đứng cạnh chúng.
    event BatchAnchored(
        bytes32 indexed hash,
        address indexed by,
        string code,
        uint32 version,
        bytes32[] inputs,
        uint64 anchoredAt
    );

    error NotAllowed();
    error ZeroAddress();

    constructor(string memory brandName) {
        owner = msg.sender;
        roleOf[msg.sender] = ROLE_BRAND;
        nameOf[msg.sender] = brandName;
        emit ActorSet(msg.sender, ROLE_BRAND, brandName);
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotAllowed();
        _;
    }

    function setOwner(address next) external onlyOwner {
        if (next == address(0)) revert ZeroAddress();
        emit OwnerChanged(owner, next);
        owner = next;
    }

    /// @notice Cấp hoặc thu hồi vai trò. Đặt `role = ROLE_NONE` là thu hồi;
    /// những gì địa chỉ đó đã neo trước đây vẫn còn nguyên trên chuỗi, đúng
    /// như bản chất của một cuốn sổ không tẩy xoá được.
    function setActor(
        address actor,
        uint8 role,
        string calldata name
    ) external onlyOwner {
        if (actor == address(0)) revert ZeroAddress();
        roleOf[actor] = role;
        nameOf[actor] = name;
        emit ActorSet(actor, role, name);
    }

    function anchorIngredient(bytes32 hash, string calldata ref) external {
        uint8 role = roleOf[msg.sender];
        if (role == ROLE_NONE) revert NotAllowed();
        emit IngredientAnchored(hash, msg.sender, ref, uint64(block.timestamp));
    }

    function anchorBatch(
        bytes32 hash,
        string calldata code,
        uint32 version,
        bytes32[] calldata inputs
    ) external {
        if (roleOf[msg.sender] != ROLE_BRAND) revert NotAllowed();
        emit BatchAnchored(
            hash,
            msg.sender,
            code,
            version,
            inputs,
            uint64(block.timestamp)
        );
    }
}
