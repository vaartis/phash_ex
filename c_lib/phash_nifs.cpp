#include <limits.h>
#include <string>

#include <erl_nif.h>

#include "pHash.h"

ERL_NIF_TERM image_hash_nif(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
    // No argument checking, it is done on the elixir side.
    // If the caller decided to call the NIFs raw, it's their problem

    ERL_NIF_TERM filepath_term = argv[0];

    ErlNifBinary path_info;
    enif_inspect_binary(env, filepath_term, &path_info);

    if (path_info.size > PATH_MAX) {
        return enif_make_tuple2(
            env,
            enif_make_atom(env, "error"),
            enif_make_string(env, "Path argument is longer than PATH_MAX. This is probably a bug in your code.", ERL_NIF_LATIN1)
        );
    }

    // Since the hashing function doesn't accept string size, the C++ string is used to constraint the size
    // to then pass that to the hashing function. Erlang strings aren't null terminated and the hashing function doesn't expect that.
    std::string path(reinterpret_cast<const char *>(path_info.data), path_info.size);

    ulong64 hash;
    int result = ph_dct_imagehash(
        path.data(),
        hash
    );
    if (result != 0) {
        return enif_make_tuple2(
            env,
            enif_make_atom(env, "error"),
            enif_make_int(env, result)
        );
    }

    return enif_make_tuple2(
        env,
        enif_make_atom(env, "ok"),
        enif_make_uint64(env, hash)
    );
}

ERL_NIF_TERM image_hash_distance_nif(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
    ulong64 a, b;

    // Once again, the type checking is done on the elixir side
    enif_get_uint64(env, argv[0], &a);
    enif_get_uint64(env, argv[1], &b);

    int result = ph_hamming_distance(a, b);

    return enif_make_int(env, result);
}

ErlNifFunc nif_funcs[] = {
    {"image_hash", 1, image_hash_nif},
    {"image_hash_distance", 2, image_hash_distance_nif}
};

ERL_NIF_INIT(Elixir.PHash.NIFs, nif_funcs, nullptr, nullptr, nullptr, nullptr);
