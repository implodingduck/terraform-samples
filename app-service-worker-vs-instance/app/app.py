import os
import uuid
from flask import (Flask, jsonify)


myuud = str(uuid.uuid4())
app = Flask(__name__)

@app.route('/')
def index():
   d = {
      "uuid": myuud,
   }
   return jsonify(d)