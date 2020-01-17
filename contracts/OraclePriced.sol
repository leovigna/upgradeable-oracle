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
  mapping(bytes32 => uint256) public _jobPricing;

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
  {
    require(_payment >= _jobPricing[_specId], "Payment too low.");

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
    // Soldity ^0.5.0 pads event data with 0
    // This leads to compatibility issues with Chainlink as nodes ignore
    // the data size. We use lower-level call to fix this issue.
    // EVENT_NON_INDEXED_ARGS
    bytes memory logData = abi.encode(
        _sender,
        requestId,
        _payment,
        _callbackAddress,
        bytes32(_callbackFunctionId), //Extend to 32bytes
        expiration,
        _dataVersion,
        _data
    );
    // Compute logDataLength to remove any padding from event log
    uint256 logDataLength = 32 * 9 + _data.length; // arg slots + data.length slot
    assembly { // solhint-disable-line no-inline-assembly
        // Skip bytes length mem position (+ 32 bytes)
        // log2() definition https://solidity.readthedocs.io/en/v0.5.3/assembly.html
        log2(add(logData, 32), logDataLength, OracleRequestTopic, _specId)
    }

  }

}