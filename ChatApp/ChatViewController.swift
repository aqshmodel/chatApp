//
//  ChatViewController.swift
//  ChatApp
//
//  Created by Takahiro Tsukada on 2019/06/09.
//  Copyright © 2019 Takahiro Tsukada. All rights reserved.
//

import UIKit
import MessageKit//追加
import InputBarAccessoryView //追加
import Firebase//追加

                        // メッセージキットのUIを使えるようにする
class ChatViewController: MessagesViewController { // <- MessagesViewControllerに必ず書き換える
    
    //外部のファイルから書き換えられないようにprivate
    private var ref: DatabaseReference! //RealtimeDatabaseの参照
    private var user: User! //ユーザー情報を入れるもの
    private var handle: DatabaseHandle!
    var messageList: [Message] = []  //Message型のオブジェクトの入る配列
    var sendData: [String: Any] = [:] //Realtimeデータベースに書き込む内容を格納する辞書
    var readData: [[String: Any]] = []
    let dateFormatter: DateFormatter = DateFormatter() //日時のフォーマットを管理するもの
    
    
    override func viewWillAppear(_ animated: Bool) {
        updateViewWhenMessageAdded() //画面が表示される直前に実行
    }
    
    // chatsを見ているobserverを解雇する処理 viewWillDisappearは画面が切り替わる直前
    override func viewWillDisappear(_ animated: Bool) {
        ref.child("chats").removeObserver(withHandle: handle)
    }
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()

        ref = Database.database().reference() //リファレンスの初期化
        user = Auth.auth().currentUser  //認証した現在のユーザーを格納
        
        //各種デリゲートをこのVCに設定  self as! <- ビックリマークを消した
        messagesCollectionView.messagesDataSource = self as MessagesDataSource
        messagesCollectionView.messagesLayoutDelegate = self as MessagesLayoutDelegate
        messagesCollectionView.messagesDisplayDelegate = self as MessagesDisplayDelegate
        messagesCollectionView.messageCellDelegate = self as MessageCellDelegate
        messageInputBar.delegate = self as InputBarAccessoryViewDelegate
        
        // メッセージ入力時に一番下までスクロール
        scrollsToBottomOnKeyboardBeginsEditing = true // default false
        // キーボードを表示しても画面がその分上にずれてくれるような処理
        maintainPositionOnKeyboardFrameChanged = true // default false
        
        /*** 次の3行を追加 ***/
        dateFormatter.dateStyle = .medium //日付の表示スタイルを決定
        dateFormatter.timeStyle = .short  //時刻の表示スタイルを決定
        dateFormatter.locale = Locale(identifier: "ja_JP")//地域を決定 日本時間
        
    }
    
    /*** ここから追加 ***/
    
    //Firebaseにチャット内容を保存するためのメソッド
    func sendMessageToFirebase(text: String){
        if !sendData.isEmpty {sendData = [:] }//辞書の初期化 辞書の中身が空じゃなかったら空にする処理
        let sendRef = ref.child("chats").childByAutoId()//自動生成の文字列の階層までのDatabaseReferenceを格納
        let messageId = sendRef.key! //自動生成された文字列(AutoId)を格納
        
        sendData = [
            "senderName": user?.displayName, //送信者の名前
            "senderId": user?.uid,           //送信者のID
            "content": text,                 //送信内容（今回は文字のみ）
            "createdAt": dateFormatter.string(from: Date()),//送信時刻
            "messageId": messageId //送信メッセージのID
        ]
        sendRef.setValue(sendData) //ここで実際にデータベースに書き込んでいます
    }
    
    /*** ここまで追加 ***/


    
    
    /*** ここから追加 ***/
    
    //メッセージが追加された際に読み込んで画面を更新するメソッド
    func updateViewWhenMessageAdded() {
        /*** 行頭の"handle = "を追加！ -> DatabaseHandleを取得 ***/
        handle = ref.child("chats").queryLimited(toLast: 25).queryOrdered(byChild: "createdAt").observe(.value) { (snapshot: DataSnapshot) in
            DispatchQueue.main.async {//クロージャの中を同期処理
                self.snapshotToArray(snapshot: snapshot)//スナップショットを配列(readData)に入れる処理。下に定義
                self.displayMessage() //メッセージを画面に表示するための処理
                print("readData: \(self.readData)")
            }
        }
    }
    
    //データベースから読み込んだデータを配列(readData)に格納するメソッド
    func snapshotToArray(snapshot: DataSnapshot){
        if !readData.isEmpty {readData = [] }
        if snapshot.children.allObjects as? [DataSnapshot] != nil  {
            let snapChildren = snapshot.children.allObjects as? [DataSnapshot]
            for snapChild in snapChildren! {
                if let postDict = snapChild.value as? [String: Any] {
                    self.readData.append(postDict)
                }
            }
        }
    }
    
    
    
    //メッセージの画面表示に関するメソッド
    func displayMessage() {
        if !messageList.isEmpty {messageList = []}
        for item in readData {
            print("item: \(item)\n")
            let message = Message(
                sender: Sender(id: item["senderId"] as! String,displayName: item["senderName"] as! String),
                messageId: item["messageId"] as! String,
                sentDate: self.dateFormatter.date(from: item["createdAt"] as! String)!,
                kind: MessageKind.text(item["content"] as! String)
            )
            messageList.append(message)
        }
        messagesCollectionView.reloadData()
        messagesCollectionView.scrollToBottom()
    }
    
    /*** ここまで追加 ***/

    
    
    
    // アラートを出す関数を定義 クロージャでBool値を返す
    func showAlert(message: String, handler: ((Bool) -> Void)?) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        let yesAction: UIAlertAction = UIAlertAction(title: "OK", style: .default){ action in
            if let handler = handler {
                handler(true) // OKを選択したらクロージャでtrueを返す
            }
        }
        let noAction: UIAlertAction = UIAlertAction(title: "キャンセル", style: .cancel){ action in
            if let handler = handler {
                handler(false) // キャンセルを選択したらクロージャでfalseを返す
            }
        }
        alert.addAction(yesAction)
        alert.addAction(noAction)
        present(alert, animated: true, completion: nil)
    }
    

} //ここまでclass




extension ChatViewController: MessagesDataSource {
    //自分の情報を設定
    func currentSender() -> SenderType {
        return Sender(senderId: user.uid, displayName: user.displayName!)
    }
    //表示するメッセージの数
    func numberOfSections(in messagesCollectionView: MessagesCollectionView) -> Int {
        return messageList.count
    }
    //メッセージの実態
    func messageForItem(at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> MessageType {
        return messageList[indexPath.section] as MessageType
    }
    
    //セルの上の文字
    func cellTopLabelAttributedText(for message: MessageType, at indexPath: IndexPath) -> NSAttributedString? {
        if indexPath.section % 3 == 0 {
            return NSAttributedString(
                string: MessageKitDateFormatter.shared.string(from: message.sentDate),
                attributes: [NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 10),
                             NSAttributedString.Key.foregroundColor: UIColor.darkGray]
            )
        }
        return nil
    }
    
    // メッセージの上の文字
    func messageTopLabelAttributedText(for message: MessageType, at indexPath: IndexPath) -> NSAttributedString? {
        let name = message.sender.displayName
        return NSAttributedString(string: name, attributes: [NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .caption1)])
    }
    
    // メッセージの下の文字
    func messageBottomLabelAttributedText(for message: MessageType, at indexPath: IndexPath) -> NSAttributedString? {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        let dateString = formatter.string(from: message.sentDate)
        return NSAttributedString(string: dateString, attributes: [NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .caption2)])
    }
}

// メッセージの見た目に関するdelegate
extension ChatViewController: MessagesDisplayDelegate {
    
    // メッセージの色を変更
    func textColor(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> UIColor {
        return isFromCurrentSender(message: message) ? .white : .darkText // 三項演算子
    }
    
    // メッセージの背景色を変更している
    func backgroundColor(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> UIColor {
        return isFromCurrentSender(message: message) ?
            UIColor(red: 69/255, green: 193/255, blue: 89/255, alpha: 1) :
            UIColor(red: 230/255, green: 230/255, blue: 230/255, alpha: 1)
    }
    
    // メッセージの枠にしっぽを付ける 吹き出し風に
    func messageStyle(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> MessageStyle {
        let corner: MessageStyle.TailCorner = isFromCurrentSender(message: message) ? .bottomRight : .bottomLeft
        return .bubbleTail(corner, .curved)
    }
    
    // アイコンをセット
    func configureAvatarView(_ avatarView: AvatarView, for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) {
        // message.sender.displayNameとかで送信者の名前を取得できるので
        // そこからイニシャルを生成するとよい
        let avatar = Avatar(initials: message.sender.displayName)
        avatarView.set(avatar: avatar)
    }
}

// 各ラベルの高さを設定（デフォルト0なので必須）、メッセージの表示位置に関するデリゲート
extension ChatViewController: MessagesLayoutDelegate {
    
    //cellTopLabelAttributedTextを表示する高さ
    func cellTopLabelHeight(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> CGFloat {
        if indexPath.section % 3 == 0 { return 10 }
        return 0
    }
    
    //messageTopLabelAttributedTextを表示する高さ 文字の位置
    func messageTopLabelHeight(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> CGFloat {
        return 16
    }
    
    //messageBottomLabelAttributedTextを表示する高さ
    func messageBottomLabelHeight(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> CGFloat {
        return 16
    }
}

extension ChatViewController: MessageCellDelegate {
    // メッセージをタップした時の挙動
    func didTapMessage(in cell: MessageCollectionViewCell) {
        print("Message tapped")
        guard let indexPath = messagesCollectionView.indexPath(for: cell) else {return}
        showAlert(message: "このメッセージを削除しますか？", handler: {showAlerted in
            
            if showAlerted {
                // OKなら削除処理を実行
                // タップしたメッセージをindexPathで読み込むインスタンス生成
                let strKey = self.readData[indexPath.section]
                // chats/個別のmessageId/ の階層を参照し、データベースから削除
//                print("ここ")
//                print(self.user.uid)
                guard strKey["senderId"]! as! String == self.user.uid  else {return}
                self.ref.child("chats/\(strKey["messageId"]!)").removeValue()
                // displayMessage()で使用しているメッセージリストからindexPathで指定したデータを削除する
                self.messageList.remove(at: indexPath.section)
                // リロードする
                self.messagesCollectionView.reloadData()
            } else {
                //キャンセルであれば何もしない
            }
        })
    }
    }



extension ChatViewController: InputBarAccessoryViewDelegate {
    // メッセージ送信ボタンを押されたとき 入力スペースが空白になり、一番下にスクロールする
    func inputBar(_ inputBar: InputBarAccessoryView, didPressSendButtonWith text: String) {
        sendMessageToFirebase(text: text)  // データベース書き込みメソッド
        inputBar.inputTextView.text = ""
        messagesCollectionView.scrollToBottom()
    }
}


