use aes::cipher::{block_padding::Pkcs7, BlockDecryptMut, BlockEncryptMut, KeyIvInit};
use base64::prelude::*;
use regex::Regex;
use sha2::{Digest, Sha256};

type Aes128CbcEnc = cbc::Encryptor<aes::Aes128>;
type Aes256CbcEnc = cbc::Encryptor<aes::Aes256>;
type Aes128CbcDec = cbc::Decryptor<aes::Aes128>;
type Aes256CbcDec = cbc::Decryptor<aes::Aes256>;

pub struct AetherCrypto;

impl AetherCrypto {
    /// Encrypts plaintext using AES-CBC with PKCS7 padding.
    /// Supports both 128-bit (16-byte) and 256-bit (32-byte) keys.
    pub fn aes_encrypt_cbc(plaintext: &[u8], key: &[u8], iv: &[u8]) -> Result<Vec<u8>, String> {
        if iv.len() != 16 {
            return Err("IV must be 16 bytes for AES-CBC".to_string());
        }

        if key.len() == 16 {
            let cipher = Aes128CbcEnc::new(key.into(), iv.into());
            let mut buf = vec![0u8; plaintext.len() + 16];
            let pt_len = plaintext.len();
            buf[..pt_len].copy_from_slice(plaintext);
            let ct = cipher
                .encrypt_padded_mut::<Pkcs7>(&mut buf, pt_len)
                .map_err(|e| format!("AES-128 encryption failed: {:?}", e))?;
            Ok(ct.to_vec())
        } else if key.len() == 32 {
            let cipher = Aes256CbcEnc::new(key.into(), iv.into());
            let mut buf = vec![0u8; plaintext.len() + 16];
            let pt_len = plaintext.len();
            buf[..pt_len].copy_from_slice(plaintext);
            let ct = cipher
                .encrypt_padded_mut::<Pkcs7>(&mut buf, pt_len)
                .map_err(|e| format!("AES-256 encryption failed: {:?}", e))?;
            Ok(ct.to_vec())
        } else {
            Err("Key must be 16 or 32 bytes for AES-CBC".to_string())
        }
    }

    /// Decrypts AES-CBC with PKCS7 padding using hardware AES-NI instructions.
    /// Supports both 128-bit (16-byte) and 256-bit (32-byte) keys.
    pub fn aes_decrypt_cbc(ciphertext: &[u8], key: &[u8], iv: &[u8]) -> Result<Vec<u8>, String> {
        if iv.len() != 16 {
            return Err("IV must be 16 bytes for AES-CBC".to_string());
        }

        let mut buf = ciphertext.to_vec();

        if key.len() == 16 {
            let cipher = Aes128CbcDec::new(key.into(), iv.into());
            let decrypted = cipher
                .decrypt_padded_mut::<Pkcs7>(&mut buf)
                .map_err(|e| format!("AES-128 decryption failed: {:?}", e))?;
            Ok(decrypted.to_vec())
        } else if key.len() == 32 {
            let cipher = Aes256CbcDec::new(key.into(), iv.into());
            let decrypted = cipher
                .decrypt_padded_mut::<Pkcs7>(&mut buf)
                .map_err(|e| format!("AES-256 decryption failed: {:?}", e))?;
            Ok(decrypted.to_vec())
        } else {
            Err("Key must be 16 or 32 bytes for AES-CBC".to_string())
        }
    }

    /// High-speed Base64 decoding.
    pub fn base64_decode(input: &str) -> Result<Vec<u8>, String> {
        BASE64_STANDARD
            .decode(input.trim())
            .map_err(|e| format!("Base64 decode error: {:?}", e))
    }

    /// High-speed Base64 encoding.
    pub fn base64_encode(input: &[u8]) -> String {
        BASE64_STANDARD.encode(input)
    }

    /// Hardware-accelerated SHA-256 hash returned as hexadecimal string.
    pub fn sha256(input: &[u8]) -> String {
        let mut hasher = Sha256::new();
        hasher.update(input);
        let result = hasher.finalize();
        format!("{:x}", result)
    }
}

pub struct AetherParser;

impl AetherParser {
    /// Extracts all capture group 1 matches for a given regex pattern.
    pub fn extract_all(input: &str, pattern: &str) -> Vec<String> {
        let re = match Regex::new(pattern) {
            Ok(r) => r,
            Err(_) => return Vec::new(),
        };

        re.captures_iter(input)
            .filter_map(|cap| cap.get(1).map(|m| m.as_str().to_string()))
            .collect()
    }

    /// Extracts the first capture group match for a regex pattern.
    pub fn extract_first(input: &str, pattern: &str) -> Option<String> {
        let re = Regex::new(pattern).ok()?;
        let cap = re.captures(input)?;
        cap.get(1).map(|m| m.as_str().to_string())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_base64_and_sha256() {
        let text = "Hello Aether Native Extensions";
        let encoded = AetherCrypto::base64_encode(text.as_bytes());
        let decoded = AetherCrypto::base64_decode(&encoded).unwrap();
        assert_eq!(String::from_utf8(decoded).unwrap(), text);

        let hash = AetherCrypto::sha256(text.as_bytes());
        assert_eq!(hash.len(), 64);
    }

    #[test]
    fn test_aes_cbc_roundtrip() {
        let key16 = b"0123456789abcdef";
        let key32 = b"0123456789abcdef0123456789abcdef";
        let iv = b"fedcba9876543210";
        let secret = b"StreamProviderSuperSecretUrlToken12345";

        // 128-bit
        let encrypted16 = AetherCrypto::aes_encrypt_cbc(secret, key16, iv).unwrap();
        let decrypted16 = AetherCrypto::aes_decrypt_cbc(&encrypted16, key16, iv).unwrap();
        assert_eq!(decrypted16, secret);

        // 256-bit
        let encrypted32 = AetherCrypto::aes_encrypt_cbc(secret, key32, iv).unwrap();
        let decrypted32 = AetherCrypto::aes_decrypt_cbc(&encrypted32, key32, iv).unwrap();
        assert_eq!(decrypted32, secret);
    }

    #[test]
    fn test_regex_extraction() {
        let html = r#"<video src="https://stream.server.com/master.m3u8" poster="poster.jpg">"#;
        let stream = AetherParser::extract_first(html, r#"src="([^"]+)""#);
        assert_eq!(stream, Some("https://stream.server.com/master.m3u8".to_string()));
    }
}
