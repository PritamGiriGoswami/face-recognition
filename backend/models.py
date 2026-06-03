from datetime import datetime
from google.cloud.firestore import DocumentReference, DocumentSnapshot

COLLECTION_ADMINS = "admins"
COLLECTION_USERS = "users"
COLLECTION_ATTENDANCE = "attendance"
COLLECTION_SETTINGS = "settings"
COLLECTION_CLASSES = "classes"
COLLECTION_DEPARTMENTS = "departments"
COLLECTION_DEVICES = "devices"
COLLECTION_ALERTS = "alerts"

SETTINGS_DOC_ID = "app_settings"

def doc_to_dict(doc: DocumentSnapshot | None):
    if doc is None or not doc.exists:
        return None
    data = doc.to_dict()
    data["id"] = doc.id
    return data

def collection_ref(db, name):
    return db.collection(name)

def doc_ref(db, collection, doc_id):
    return db.collection(collection).document(str(doc_id))

def auto_id(db, collection):
    return db.collection(collection).document().id
