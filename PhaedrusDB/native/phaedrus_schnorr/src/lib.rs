use rand::rngs::OsRng;
use rustler::{Binary, Env, NifResult, OwnedBinary};
use secp256k1::{schnorr::Signature, Keypair, Secp256k1, SecretKey, XOnlyPublicKey};

rustler::init!(
    "Elixir.PhaedrusDB.Schnorr",
    [pubkey_from_privkey, sign_hash, verify_hash]
);

fn bin_from_slice<'a>(env: Env<'a>, bytes: &[u8]) -> NifResult<Binary<'a>> {
    let mut ob = OwnedBinary::new(bytes.len()).ok_or(rustler::Error::Atom("alloc_failed"))?;
    ob.as_mut_slice().copy_from_slice(bytes);
    Ok(Binary::from_owned(ob, env))
}

#[rustler::nif]
fn pubkey_from_privkey<'a>(env: Env<'a>, privkey: Binary<'a>) -> NifResult<Binary<'a>> {
    let secp = Secp256k1::new();
    let sk = SecretKey::from_slice(privkey.as_slice())
        .map_err(|_| rustler::Error::Term(Box::new("bad_privkey")))?;
    let keypair = Keypair::from_secret_key(&secp, &sk);
    let (xonly, _parity) = XOnlyPublicKey::from_keypair(&keypair);

    let bytes = xonly.serialize();
    bin_from_slice(env, &bytes)
}

#[rustler::nif]
fn sign_hash<'a>(env: Env<'a>, hash32: Binary<'a>, privkey: Binary<'a>) -> NifResult<Binary<'a>> {
    let secp = Secp256k1::new();

    let msg = hash32.as_slice();
    if msg.len() != 32 {
        return Err(rustler::Error::Term(Box::new("bad_hash_len")));
    }

    let sk = SecretKey::from_slice(privkey.as_slice())
        .map_err(|_| rustler::Error::Term(Box::new("bad_privkey")))?;
    let keypair = Keypair::from_secret_key(&secp, &sk);

    let mut rng = OsRng;
    let sig: Signature = secp.sign_schnorr_with_rng(msg, &keypair, &mut rng);

    let bytes = sig.as_ref();
    bin_from_slice(env, bytes)
}

#[rustler::nif]
fn verify_hash(hash32: Binary, sig64: Binary, pubkey32: Binary) -> bool {
    let secp = Secp256k1::new();

    let msg = hash32.as_slice();
    if msg.len() != 32 {
        return false;
    }

    let pk = match XOnlyPublicKey::from_slice(pubkey32.as_slice()) {
        Ok(p) => p,
        Err(_) => return false,
    };

    let sig = match Signature::from_slice(sig64.as_slice()) {
        Ok(s) => s,
        Err(_) => return false,
    };

    secp.verify_schnorr(&sig, msg, &pk).is_ok()
}
