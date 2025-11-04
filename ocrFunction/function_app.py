import azure.functions as func
import logging
import requests
from azure.cognitiveservices.vision.computervision import ComputerVisionClient
from msrest.authentication import CognitiveServicesCredentials
from json import dumps
import os

app = func.FunctionApp()

@app.route(route="ocr", methods=["POST"], auth_level=func.AuthLevel.FUNCTION)
def process_ocr(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('Python HTTP trigger function processed an OCR request.')

    try:
        image_url = req.params.get('image_url')
        if not image_url:
            req_body = req.get_json()
            image_url = req_body.get('image_url')

        if image_url:
            # OCR processing
            ocr_result = perform_ocr(image_url)
            return func.HttpResponse(dumps(ocr_result), status_code=200)
        else:
            return func.HttpResponse(
                "Please pass an image URL on the query string or in the request body",
                status_code=400
            )
    except ValueError as e:
        logging.error(f"Error parsing request: {str(e)}")
        return func.HttpResponse(
            "Error parsing request body or query parameters.",
            status_code=400
        )
    except Exception as e:
        logging.error(f"General error in process_ocr function: {str(e)}")
        return func.HttpResponse(
            "An error occurred in the OCR processing function.",
            status_code=500
        )

def perform_ocr(image_url: str) -> dict:
    try:
        # Azure Computer Vision credentials
        subscription_key = os.environ["COMPUTER_VISION_SUBSCRIPTION_KEY"]
        endpoint = os.environ["COMPUTER_VISION_ENDPOINT"]

        # Authenticate Computer Vision client
        computervision_client = ComputerVisionClient(
            endpoint, 
            CognitiveServicesCredentials(subscription_key)
        )

        # Call the OCR API using the image URL
        ocr_result = computervision_client.recognize_printed_text(url=image_url, language='pl')

        # Extract and format the text
        lines = [word.text for region in ocr_result.regions for line in region.lines for word in line.words]
        return {'text': ' '.join(lines)}
    except Exception as e:
        logging.error(f"Error in perform_ocr: {str(e)}")
        raise  # Re-raise the exception to be handled in the calling function
