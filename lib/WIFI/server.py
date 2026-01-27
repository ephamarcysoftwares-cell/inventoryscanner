from flask import Flask, jsonify, request
import sqlite3
import os

app = Flask(__name__)
# ⚠️ CRUCIAL: SET THE EXACT DIRECTORY WHERE 'epharmacy.db' IS LOCATED
DB_DIR = r'C:\Users\Public\epharmacy' # Example path - change this!
DB_PATH = os.path.join(DB_DIR, 'epharmacy.db')

def get_db_connection():
    """Establishes a connection to the SQLite database."""
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn

def execute_db_query(query, args=None, commit=False):
    """Utility function to execute a query and handle connection closing."""
    conn = None
    try:
        conn = get_db_connection()
        c = conn.cursor()
        if args:
            c.execute(query, args)
        else:
            c.execute(query)

        if commit:
            conn.commit()
            return c.rowcount
        else:
            cols = [desc[0] for desc in c.description]
            rows = c.fetchall()
            return [dict(zip(cols, row)) for row in rows]
    except sqlite3.Error as e:
        print(f"SQLite Error: {e}")
        raise
    finally:
        if conn:
            conn.close()

# -----------------------------------------------------------
# API ROUTES/
# -----------------------------------------------------------

# ✨ NEW ROUTE: Handles Remote User Login
@app.route('/login', methods=['POST'])
def login_user():
    """Authenticates a user by email and HASHED password."""
    data = request.get_json(silent=True)
    if not data or 'email' not in data or 'password' not in data:
        return jsonify({'error': 'Missing email or password'}), 400

    email = data['email']
    # The 'password' received here is the HASHED password from Flutter
    hashed_password = data['password'] 

    try:
        # Query the database for a user matching both email and HASHED password
        # NOTE: Ensure your stored password hashes match Flutter's sha256.
        query = "SELECT id, full_name, email, role, phone FROM users WHERE email = ? AND password = ?"
        user_data = execute_db_query(query, (email, hashed_password))

        if user_data:
            return jsonify(user_data[0]), 200
        else:
            return jsonify({'error': 'Invalid credentials'}), 401
    except Exception as e:
        print(f"Database error during remote login: {e}")
        return jsonify({'error': f'Failed to perform remote login: {e}'}), 500


@app.route('/medicines', methods=['GET'])
def get_medicines():
    """Fetches all data from the 'medicines' table."""
    try:
        medicines = execute_db_query('SELECT * FROM medicines')
        return jsonify(medicines)
    except Exception as e:
        return jsonify({'error': f'Failed to fetch medicines: {e}'}), 500

@app.route('/save_cart', methods=['POST'])
def save_cart_item():
    """Inserts a new medicine item into the cart table."""
    data = request.get_json(silent=True)
    
    required_fields = [
        'user_id', 'medicine_id', 'medicine_name', 'company', 
        'price', 'quantity', 'unit', 'date_added', 'source'
    ]
    if not data or not all(field in data for field in required_fields):
        missing_fields = [field for field in required_fields if field not in data]
        print(f"Missing fields in /save_cart POST: {missing_fields}")
        return jsonify({'error': 'Missing required data fields from Flutter payload.'}), 400

    try:
        user_id = data['user_id']
        medicine_id = data['medicine_id']
        medicine_name = data['medicine_name']
        company = data['company']
        price = data['price']
        quantity = data['quantity']
        unit = data['unit']
        date_added = data['date_added']
        source = data['source']
        business_name = None # Not sent by Flutter
    except KeyError as e:
        return jsonify({'error': f'Payload is missing a required key: {e}'}), 400

    query = """
    INSERT INTO cart (
        user_id, medicine_id, medicine_name, company, price, 
        quantity, unit, date_added, source, business_name
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    """
    args = (
        user_id, medicine_id, medicine_name, company, price, 
        quantity, unit, date_added, source, business_name
    )
    
    try:
        rows_affected = execute_db_query(query, args, commit=True)
        if rows_affected > 0:
            return jsonify({'message': 'Cart item saved successfully.'}), 201
        else:
            return jsonify({'message': 'Failed to save cart item.'}), 500
    except Exception as e:
        print(f"Database error saving cart item: {e}")
        return jsonify({'error': f'Failed to save cart item: {e}'}), 500


@app.route('/update_stock', methods=['POST'])
def update_stock():
    """Updates the remaining quantity of a medicine after a sale."""
    data = request.get_json(silent=True)
    if not data or 'medicine_id' not in data or 'remaining_quantity' not in data:
        return jsonify({'error': 'Missing data fields (medicine_id, remaining_quantity)'}), 400

    try:
        medicine_id = data['medicine_id']
        remaining_quantity = data['remaining_quantity']
        
        if not isinstance(remaining_quantity, int) or not isinstance(medicine_id, int):
            return jsonify({'error': 'medicine_id and remaining_quantity must be integers.'}), 400

        query = 'UPDATE medicines SET remaining_quantity = ? WHERE id = ?'
        rows_affected = execute_db_query(query, (remaining_quantity, medicine_id), commit=True)
        
        if rows_affected == 0:
            return jsonify({'message': 'Medicine not found or no change made.'}), 404
            
        return jsonify({'message': 'Stock updated successfully.'}), 200
    except Exception as e:
        return jsonify({'error': f'Stock update failed: {e}'}), 500


@app.route('/business_info', methods=['GET'])
def get_business_info():
    """Fetches data from the 'businesses' table."""
    try:
        info = execute_db_query('SELECT * FROM businesses LIMIT 1')
        if info:
            return jsonify(info[0])
        return jsonify({}), 404
    except Exception as e:
        return jsonify({'error': f'Failed to fetch business info: {e}'}), 500


if __name__ == '__main__':
    print(f"Database path: {DB_PATH}")
    app.run(host='0.0.0.0', port=8080, debug=True)