use std::{collections::HashMap, fmt::Debug, print};

use axum::{
    Json, Router, body::to_bytes, extract::Request, http::{HeaderValue, header::CONTENT_TYPE}, routing::get,
};
use serde_json::{Value, json};

const CONTENT_TYPE_JSON: &str = "application/json";
const CONTENT_TYPE_JSON_AXUM: HeaderValue = HeaderValue::from_static(CONTENT_TYPE_JSON);

#[tokio::main]
async fn main() {
    // build our application with a single route
    let app = Router::new()
    .fallback(print_data);

    // run our app with hyper, listening globally on port 3000
    let listener = tokio::net::TcpListener::bind("0.0.0.0:3000").await.unwrap();
    axum::serve(listener, app).await.unwrap();
}


async fn print_data(req: Request) -> Json<serde_json::Value> {
    print!("-----------------Start Request data-----------------\n");
    let (parts, body) = req.into_parts();

    let body_data = to_bytes(body, usize::MAX).await.unwrap();
    let body_data: Value =  if parts.headers.get(CONTENT_TYPE) == Some(&CONTENT_TYPE_JSON_AXUM) {
        json!(&serde_json::from_slice(&body_data).unwrap_or(json!({})))
    } else {
        json!(String::from_utf8_lossy(&body_data).to_string())
    };


    let method = parts.method;
    let uri = parts.uri;
    let headers = parts.headers;
    let version = parts.version;

    print!("Method: {:?}\nURI: {:?}\nHeaders: {:?}\nBody: {:?}\nVersion: {:?}\n", method, uri, headers, body_data, version );
    print!("-----------------End Request data-----------------\n\n\n\n");

    Json(json!({
        "method": method.to_string(),
        "uri": uri.to_string(),
        "headers": headers.iter().map(|(k, v)| (k.to_string(), v.to_str().unwrap_or("").to_string())).collect::<HashMap<_,_>>(),
        "body": body_data,
        "version": format!("{:?}", version),
    }))

}