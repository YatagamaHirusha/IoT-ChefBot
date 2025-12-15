#include <Arduino.h>
#include "esp_camera.h"
#include "esp_http_server.h"

httpd_handle_t camera_httpd = NULL;

static esp_err_t capture_handler(httpd_req_t *req) {
    camera_fb_t * fb = esp_camera_fb_get();
    if(!fb) {
        httpd_resp_send_500(req);
        return ESP_FAIL;
    }
    httpd_resp_set_type(req, "image/jpeg");
    httpd_resp_send(req, (const char *)fb->buf, fb->len);
    esp_camera_fb_return(fb);
    return ESP_OK;
}

static esp_err_t stream_handler(httpd_req_t *req){
    char part_buf[64];
    camera_fb_t * fb = NULL;
    esp_err_t res = ESP_OK;
    res = httpd_resp_set_type(req, "multipart/x-mixed-replace; boundary=frame");
    if(res != ESP_OK) return res;

    while(true){
        fb = esp_camera_fb_get();
        if(!fb){
            Serial.println("Camera capture failed");
            continue;
        }
        size_t hlen = snprintf(part_buf, 64,
                               "--frame\r\nContent-Type: image/jpeg\r\nContent-Length: %u\r\n\r\n",
                               (unsigned int)fb->len);
        res = httpd_resp_send_chunk(req, part_buf, hlen);
        if(res != ESP_OK){
            esp_camera_fb_return(fb);
            break;
        }
        res = httpd_resp_send_chunk(req, (const char*)fb->buf, fb->len);
        esp_camera_fb_return(fb);
        if(res != ESP_OK) break;
        res = httpd_resp_send_chunk(req, "\r\n", 2);
        if(res != ESP_OK) break;
    }
    return res;
}

void startCameraServer() {
    httpd_config_t config = HTTPD_DEFAULT_CONFIG();
    if(httpd_start(&camera_httpd, &config) == ESP_OK){
        httpd_uri_t capture_uri = {
            .uri = "/capture",
            .method = HTTP_GET,
            .handler = capture_handler,
            .user_ctx = NULL
        };
        httpd_register_uri_handler(camera_httpd, &capture_uri);

        httpd_uri_t stream_uri = {
            .uri = "/stream",
            .method = HTTP_GET,
            .handler = stream_handler,
            .user_ctx = NULL
        };
        httpd_register_uri_handler(camera_httpd, &stream_uri);
    }
}
