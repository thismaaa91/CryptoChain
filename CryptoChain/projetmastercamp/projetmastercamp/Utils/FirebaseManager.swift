//
//  FirebaseManager.swift
//  projetmastercamp
//
//  Created by Vincent Retkowsky on 29/06/2022.
//

import Foundation
import Firebase
import FirebaseStorage
import FirebaseFirestore

class FirebaseManager: NSObject {
    
    let auth: Auth
    let storage : Storage
    let firestore: Firestore
    static let shared = FirebaseManager()
    override init(){
        FirebaseApp.configure()
        self.auth = Auth.auth()
        self.storage = Storage.storage()
        self.firestore = Firestore.firestore()
        super.init()
    }
}
