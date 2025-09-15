#from langchain.vectorstores import FAISS
from langchain_community.vectorstores import FAISS
import os

from app.components.embeddings import get_embedding_model
from app.common.logger import get_logger
from app.common.custom_exception import CustomException

from app.config.config import DB_FAISS_PATH

logger = get_logger(__name__)

def load_vector_store():
    try:
        embedding_model = get_embedding_model()

        if os.path.exists(DB_FAISS_PATH):
            logger.info("loading existing vector store")
            return FAISS.load_local (
                DB_FAISS_PATH,
                embedding_model,
                allow_dangerous_deserialization=True
            )
        else:
            logger.warning("no vectore store found ..")


    except Exception as e:
        error_message = CustomException('Failed to load vector store')  
        logger.error(str(error_message)) 


# Create a new vector store method function
def save_vector_store(text_chunks):
    try:
        if not text_chunks:
            raise CustomException("No chunks were found..")
        
        logger.info("Generating your new vectorstore")

        embedding_model = get_embedding_model()

        db = FAISS.from_documents(text_chunks,embedding_model)

        logger.info("Saving vectorstoree")

        db.save_local(DB_FAISS_PATH)

        logger.info("Vectostore saved sucesfulyy...")

        return db
    
    except Exception as e:
        error_message = CustomException("Failed to craete new vectorstore " , e)
        logger.error(str(error_message))
