//
//  ChatLogView.swift
//  projetmastercamp
//
//  Created by Vincent Retkowsky on 30/06/2022.
//

import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseDatabase
import FirebaseFirestoreSwift
import FirebaseCore
import FirebaseFunctions
import SDWebImageSwiftUI

struct FirebaseConstants {
    static let fromId = "fromId"
    static let toId = "toId"
    static let text = "text"
    static let timestamp = "timestamp"
    static let profileImageUrl = "profileImageUrl"
    static let email = "email"


}

struct ChatMessage: Identifiable{
    var id: String{ documentId}
    let documentId: String
    let fromId, toId, text: String
    init(documentId: String, data: [String: Any]){
        self.documentId = documentId
        self.fromId = data[FirebaseConstants.fromId] as? String ?? ""
        self.toId = data[FirebaseConstants.toId] as? String ?? ""
        self.text = data[FirebaseConstants.text] as? String ?? ""
    }
}

class ChatLogViewModel: ObservableObject{
    
    @Published var chatText = ""
    @Published var errorMessage = ""
    @Published var chatMessages = [ChatMessage]()

    let chatUser: ChatUser?
        
    init(chatUser: ChatUser?){
        self.chatUser = chatUser
        fetchMessages()
    }
    private func fetchMessages(){
        guard let fromId = FirebaseManager.shared.auth.currentUser?.uid else {return}
        
        guard let toId = chatUser?.uid else {return}
        FirebaseManager.shared.firestore.collection("messages")
            .document(fromId)
            .collection(toId)
            .order(by: "timestamp")
            .addSnapshotListener { querySnapshot, error in
                if let error = error{
                    self.errorMessage = "Failed to listen to message \(error)"
                    print(error)
                    return
                }
                querySnapshot?.documentChanges.forEach({ change in
                    if change.type == .added{
                        let data = change.document.data()
                        self.chatMessages.append(.init(documentId: change.document.documentID, data: data))
                        print("Appending chat message")
                    }
                })
                DispatchQueue.main.async{
                    self.count += 1
                }
            }
    }
    
    func handleSend(){
        print(chatText)
        // chiffrer ici
        guard let fromId = FirebaseManager.shared.auth.currentUser?.uid else {return}

        guard let toId = chatUser?.uid else {return}
    
        let document = FirebaseManager.shared.firestore.collection("messages")
            .document(fromId)
            .collection(toId)
            .document()
    
        let messageData = [FirebaseConstants.fromId: fromId, FirebaseConstants.toId: toId, FirebaseConstants.text: self.chatText, "timestamp": Timestamp()] as [String : Any]
        document.setData(messageData){error in
            if let error = error{
                print(error)
                self.errorMessage = "Failed to save messages into Firestore\(error)"
                return
            }
            print("Successfully savedcurrent user sending message")
            persistRecentMessage()
            self.chatText = ""
            self.count += 1
        }
        let recipientMessageDocument = FirebaseManager.shared.firestore.collection("messages")
            .document(toId)
            .collection(fromId)
            .document()
        
        recipientMessageDocument.setData(messageData){error in
            if let error = error{
                print(error)
                self.errorMessage = "Failed to save messages into Firestore\(error)"
                return
            }
            print("Recipient saved message r")
        }
    
    
        func persistRecentMessage(){
            guard let chatUser = chatUser else {
                return
            }

            guard let uid = FirebaseManager.shared.auth.currentUser?.uid else {return}
    
            guard let toId = self.chatUser?.uid else {return}
            let document = FirebaseManager.shared.firestore
                .collection("recent_messages")
                .document(uid)
                .collection("messages")
                .document(toId)
            let data = [
                FirebaseConstants.timestamp: Timestamp(),
                FirebaseConstants.text: self.chatText,
                FirebaseConstants.fromId: uid,
                FirebaseConstants.toId: toId,
                FirebaseConstants.profileImageUrl: chatUser.profileImageUrl,
                FirebaseConstants.email: chatUser.email
            ] as [String : Any]
            document.setData(data) { error in
                if let error = error{
                    self.errorMessage = "Failed to save recent message: \(error)"
                    print("Failed to save recent message: \(error)")
                    return
                }
            }
        }
    }
    @Published var count = 0
}





struct ChatLogView: View{
//    let chatUser: ChatUser?
//    init(chatUser: ChatUser?){
//        self.chatUser = chatUser
//        self.vm = .init(chatUser: chatUser)
//    }
    @ObservedObject var vm: ChatLogViewModel
    var body: some View{
        
        VStack{
            messagesView
            Text(vm.errorMessage)
            chatBottomBar
                .background(Color(.init(white: 0.9, alpha: 1)))
        }
        .navigationTitle(vm.chatUser?.email ?? "")
        .navigationBarTitleDisplayMode(.inline)
//            .navigationBarItems(trailing: Button(action: {
     //           vm.count += 1
 //           }, label: {
  //              Text("Count: \(vm.count)")
  //          }))
    }
    
    static let emptyScrollToString = "Empty"
    
    private var messagesView: some View{
        ScrollView{
            ScrollViewReader{ ScrollViewProxy in
                VStack{
                    ForEach(vm.chatMessages){ message in
                        MessageView(message: message)
                    }
                    HStack{
                        Spacer()
                    }
                    .background(Color(.init(white: 0.9, alpha: 1)))
                    .id(Self.emptyScrollToString)
                }
                .onReceive(vm.$count) { _ in
                    withAnimation (.easeOut(duration: 0.5)){
                        ScrollViewProxy.scrollTo(Self.emptyScrollToString, anchor: .bottom)

                    }
                }
               
                
            }
            

        }
    }
    
    struct MessageView: View{
        let message: ChatMessage
        var body: some View{
            VStack{
                if message.fromId == FirebaseManager.shared.auth.currentUser?.uid{
                    HStack{
                        Spacer()
                        HStack{
                            //déchiffrer ici
                            Text(message.text)
                                .foregroundColor(.white)
                        }
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(8)
                    }

                }else{
                    HStack{
                        HStack{
                            //déchiffrer ici
                            Text(message.text)
                                .foregroundColor(.black)
                        }
                        .padding()
                        .background(Color(.init(white: 0.9, alpha: 1)))
                        .cornerRadius(8)
                        Spacer()
                    }

                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
    }
    
    private var chatBottomBar: some View{
        HStack(spacing: 16){
            Image(systemName: "photo.on.rectangle")
                .font(.system(size: 24))
                .foregroundColor(Color(.darkGray))
          //  TextEditor(text: $chatText)
            TextField("Description", text: $vm.chatText)
            Button {
                vm.handleSend()
            } label: {
                Text("Send")
                    .foregroundColor(.white)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.blue)
            .cornerRadius(4)

        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

struct ChatLogView_Previews: PreviewProvider {
    static var previews: some View {
//        NavigationView{
  //          ChatLogView(chatUser: .init(data: ["uid": "yUa6ZidBk6VJiYHuBE0LVAJohjQ2", "email": "fake@gmail.com"]))
        MainMessagesView()
    }
}

