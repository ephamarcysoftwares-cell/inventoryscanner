 <?php
define('APP_ENVIROMENT', 'live'); // sandbox or live

if (APP_ENVIROMENT == 'sandbox') {
    $apiUrl = "https://cybqa.pesapal.com/pesapalv3/api/Auth/RequestToken"; // Sandbox URL
    $consumerKey = "72CeUDOSt+U05/2DNkuhMiarfE36c7M+";
    $consumerSecret = "skdqX0IcjNLigCDcuBePSii/vuc=";
} elseif (APP_ENVIROMENT == 'live') {
    $apiUrl = "https://pay.pesapal.com/v3/api/Auth/RequestToken"; // Live URL
    $consumerKey = "72CeUDOSt+U05/2DNkuhMiarfE36c7M+";
    $consumerSecret = "skdqX0IcjNLigCDcuBePSii/vuc=";
} else {
    die("Invalid APP_ENVIROMENT");
}

$headers = [
    "Accept: application/json",
    "Content-Type: application/json"
];

$data = [
    "consumer_key" => $consumerKey,
    "consumer_secret" => $consumerSecret
];

$ch = curl_init($apiUrl);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_POST, true);
curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($data));
curl_setopt($ch, CURLOPT_HTTPHEADER, $headers);
$response = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);

if ($httpCode == 200) {
    $data = json_decode($response);
    if (isset($data->token)) {
        $token = $data->token;
        $_SESSION['pesapal_token'] = $token; // ✅ Store in session (not displayed)
    } else {
        error_log("Pesapal Token Error: Token not found in response."); // ✅ Log instead of displaying
    }
} else {
    error_log("Pesapal API Error: HTTP Code: $httpCode. Response: $response"); // ✅ Log instead of displaying
}
?>
