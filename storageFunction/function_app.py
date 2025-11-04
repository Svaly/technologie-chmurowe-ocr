import azure.functions as func
import logging
import os
from azure.storage.blob import BlobServiceClient, BlobSasPermissions, generate_blob_sas
from datetime import datetime, timedelta
import uuid
from io import BytesIO

app = func.FunctionApp()

@app.route(route="uploadimage", methods=["POST"], auth_level=func.AuthLevel.FUNCTION)
async def upload_image(req: func.HttpRequest) -> func.HttpResponse:
    try:
        # Retrieve the image file from form data
        image_file = req.files["file"]

        # Open the image using PIL
        image_data = BytesIO(image_file.read())

        if not image_data:
            return func.HttpResponse(
                "No image data found in the request.",
                status_code=400
            )

        # Blob Storage details
        account_name = os.environ["OCR_STORAGE_ACCOUNT_NAME"]
        account_key = os.environ["OCR_STORAGE_ACCOUNT_KEY"]
        container_name = os.environ["OCR_STORAGE_ACCOUNT_CONTAINER_NAME"]

        # Create Blob Service Client
        blob_service_client = BlobServiceClient.from_connection_string(
            f"DefaultEndpointsProtocol=https;AccountName={account_name};AccountKey={account_key};EndpointSuffix=core.windows.net"
        )

        # Generate unique blob name
        blob_name = f"image_{uuid.uuid4()}.png"

        # Upload image to Blob Storage
        blob_client = blob_service_client.get_blob_client(container=container_name, blob=blob_name)
        blob_client.upload_blob(image_data)

        # Generate SAS token
        sas_token = generate_blob_sas(
            account_name=account_name,
            container_name=container_name,
            blob_name=blob_name,
            account_key=account_key,
            permission=BlobSasPermissions(read=True),
            expiry=datetime.utcnow() + timedelta(days=14)  # 14 days validity
        )

        # Construct Blob URL with SAS token
        blob_url_with_sas = f"https://{account_name}.blob.core.windows.net/{container_name}/{blob_name}?{sas_token}"

        return func.HttpResponse(blob_url_with_sas, status_code=200)
    except Exception as e:
        logging.error(f"Error in upload_image function: {str(e)}")
        return func.HttpResponse(
            "An error occurred in the image upload function.",
            status_code=500
        )