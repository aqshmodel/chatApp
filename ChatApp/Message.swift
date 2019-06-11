//
//  Message.swift
//  ChatApp
//
//  Created by Takahiro Tsukada on 2019/06/09.
//  Copyright © 2019 Takahiro Tsukada. All rights reserved.
//


// MessageKitの中にあるMessageTypeを継承したMessageという名前の構造体を定義してます。

import Foundation
import MessageKit

struct Message: MessageType { //classではなくstruct!
    var sender: SenderType
    var messageId: String
    var sentDate: Date
    var kind: MessageKind

}

