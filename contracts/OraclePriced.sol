pragma solidity ^0.5.0;

import "./OracleUpgradeable.sol";

/**
 * @title The Chainlink Oracle contract (OZ Upgradeable version + Job level pricing)
 * @notice Node operators can deploy this contract to fulfill requests sent to them
 * @dev Upgradeable version of Oracle contract.
 *      Uses OpenZeppelin's Initializable, Ownable contracts.
 *      Also includes job level pricing by creating checkJobPricing modifier.
 */
contract OraclePriced is OracleUpgradeable {

  // Adds a new storage slot for pricing.
  // Author suggests becoming familiar with OpenZeppelin Proxy pattern.
  mapping(bytes32 => uint256) private _jobPricing;

  modifier checkJobPricing(bytes32 _specId, uint256 _payment) {
    require(_payment >= _jobPricing[_specId], "Payment too low.");
    _;
  }

  function setJobPricing(uint256 _payment, bytes32 _specId) external onlyOwner {
      _jobPricing[_specId] = _payment;
  }

  /**
   * @notice Creates the Chainlink request
   * @dev Stores the hash of the params as the on-chain commitment for the request.
   * Emits OracleRequest event for the Chainlink node to detect. 
   * Overrides original version to validate job pricing.
   * @param _sender The sender of the request
   * @param _payment The amount of payment given (specified in wei)
   * @param _specId The Job Specification ID
   * @param _callbackAddress The callback address for the response
   * @param _callbackFunctionId The callback function ID for the response
   * @param _nonce The nonce sent by the requester
   * @param _dataVersion The specified data version
   * @param _data The CBOR payload of the request
   */
  function oracleRequest(
    address _sender,
    uint256 _payment,
    bytes32 _specId,
    address _callbackAddress,
    bytes4 _callbackFunctionId,
    uint256 _nonce,
    uint256 _dataVersion,
    bytes calldata _data
  )
    external
    onlyLINK
    checkCallbackAddress(_callbackAddress)
    checkJobPricing(_specId, _payment)
  {
    bytes32 requestId = keccak256(abi.encodePacked(_sender, _nonce));
    require(commitments[requestId] == 0, "Must use a unique ID");
    // solhint-disable-next-line not-rely-on-time
    uint256 expiration = now.add(EXPIRY_TIME);

    commitments[requestId] = keccak256(
      abi.encodePacked(
        _payment,
        _callbackAddress,
        _callbackFunctionId,
        expiration
      )
    );

    emit OracleRequest(
      _specId,
      _sender,
      requestId,
      _payment,
      _callbackAddress,
      _callbackFunctionId,
      expiration,
      _dataVersion,
      _data);
  }

}