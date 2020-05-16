//
//  NWParameters.swift
//  PearToPearNetwork
//
//  Created by melisa öztürk on 16.05.2020.
//  Copyright © 2020 melisa öztürk. All rights reserved.
//

import Foundation
import Network
import CryptoKit

class Encode {

    static var shared = Encode()
    // Create TLS options using a passcode to derive a pre-shared key.
    static func dtlsOptions(data: Data) -> NWProtocolTLS.Options {
        let dtlsOptions = NWProtocolTLS.Options()

        let authenticationKey = SymmetricKey(data: data)
        var authenticationCode = HMAC<SHA256>.authenticationCode(for: "TicTacToe".data(using: .utf8)!, using: authenticationKey)

        let authenticationDispatchData = withUnsafeBytes(of: &authenticationCode) { (ptr: UnsafeRawBufferPointer) in
            DispatchData(bytes: ptr)
        }

        sec_protocol_options_add_pre_shared_key(dtlsOptions.securityProtocolOptions,
                                                authenticationDispatchData as __DispatchData,
                                                stringToDispatchData("TicTacToe")! as __DispatchData)
        sec_protocol_options_append_tls_ciphersuite(dtlsOptions.securityProtocolOptions,
                                                    tls_ciphersuite_t(rawValue: TLS_PSK_WITH_AES_128_GCM_SHA256)!)
        return dtlsOptions
    }

    // Create a utility function to encode strings as pre-shared key data.
    private static func stringToDispatchData(_ string: String) -> DispatchData? {
        guard let stringData = string.data(using: .unicode) else {
            return nil
        }
        let dispatchData = withUnsafeBytes(of: stringData) { (ptr: UnsafeRawBufferPointer) in
            DispatchData(bytes: UnsafeRawBufferPointer(start: ptr.baseAddress, count: stringData.count))
        }
        return dispatchData
    }
}
