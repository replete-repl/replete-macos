//
//  RepleteHelpers.m
//  Relete-OSX
//
//  Created by Jason Jobe on 4/7/19.
//  Copyright © 2019 Jason Jobe. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <JavaScriptCore/JavaScriptCore.h>

#include <pthread.h>
#include <mach/mach_time.h>
#include "jsc_utils.h"
#include "functions.h"
#include "io.h"
#include "file.h"
#include "http.h"
#include "bundle.h"

#if 0

void register_global_function(JSContextRef ctx, char *name, JSObjectCallAsFunctionCallback handler) {
    JSObjectRef global_obj = JSContextGetGlobalObject(ctx);

    JSStringRef fn_name = JSStringCreateWithUTF8CString(name);
    JSObjectRef fn_obj = JSObjectMakeFunctionWithCallback(ctx, fn_name, handler);

    JSObjectSetProperty(ctx, global_obj, fn_name, fn_obj, kJSPropertyAttributeNone, NULL);
}

int str_has_prefix(const char *str, const char *prefix) {
    size_t len = strlen(str);
    size_t prefix_len = strlen(prefix);

    if (len < prefix_len) {
        return -1;
    }

    return strncmp(str, prefix, prefix_len);
}

unsigned long hash(unsigned char *str) {
    unsigned long hash = 5381;
    int c;

    while ((c = *str++))
        hash = ((hash << 5) + hash) + c; /* hash * 33 + c */

    return hash;
}

static unsigned long loaded_goog_hashes[2048];
static size_t count_loaded_goog_hashes = 0;

bool is_loaded(unsigned long h) {
    size_t i;
    for (i = 0; i < count_loaded_goog_hashes; ++i) {
        if (loaded_goog_hashes[i] == h) {
            return true;
        }
    }
    return false;
}

void add_loaded_hash(unsigned long h) {
    if (count_loaded_goog_hashes < 2048) {
        loaded_goog_hashes[count_loaded_goog_hashes++] = h;
    }
}

JSGlobalContextRef ctx = NULL;

JSValueRef function_import_script(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject,
                                  size_t argc, const JSValueRef args[], JSValueRef *exception) {
    if (argc == 1 && JSValueGetType(ctx, args[0]) == kJSTypeString) {
        JSStringRef path_str_ref = JSValueToStringCopy(ctx, args[0], NULL);
        assert(JSStringGetLength(path_str_ref) < PATH_MAX);
        char tmp[PATH_MAX];
        tmp[0] = '\0';
        JSStringGetUTF8CString(path_str_ref, tmp, PATH_MAX);
        JSStringRelease(path_str_ref);

        bool can_skip_load = false;
        char *path = tmp;
        if (str_has_prefix(path, "goog/../") == 0) {
            path = path + 8;
        } else {
            unsigned long h = hash((unsigned char *) path);
            if (is_loaded(h)) {
                can_skip_load = true;
            } else {
                add_loaded_hash(h);
            }
        }

        if (!can_skip_load) {
            char *source = bundle_get_contents(path);
            if (source != NULL) {
                evaluate_script(ctx, source, path);
                free(source);
            } else {
                NSLog(@"Failed to get source for %s", path);
            }
        }
    }

    return JSValueMakeUndefined(ctx);
}

pthread_mutex_t eval_lock = PTHREAD_MUTEX_INITIALIZER;

void acquire_eval_lock() {
    pthread_mutex_lock(&eval_lock);
}

void release_eval_lock() {
    pthread_mutex_unlock(&eval_lock);
}


char *munge(char *s) {
    size_t len = strlen(s);
    size_t new_len = 0;
    int i;
    for (i = 0; i < len; i++) {
        switch (s[i]) {
            case '!':
                new_len += 6; // _BANG_
                break;
            case '?':
                new_len += 7; // _QMARK_
                break;
            default:
                new_len += 1;
        }
    }

    char *ms = malloc((new_len + 1) * sizeof(char));
    int j = 0;
    for (i = 0; i < len; i++) {
        switch (s[i]) {
            case '-':
                ms[j++] = '_';
                break;
            case '!':
                ms[j++] = '_';
                ms[j++] = 'B';
                ms[j++] = 'A';
                ms[j++] = 'N';
                ms[j++] = 'G';
                ms[j++] = '_';
                break;
            case '?':
                ms[j++] = '_';
                ms[j++] = 'Q';
                ms[j++] = 'M';
                ms[j++] = 'A';
                ms[j++] = 'R';
                ms[j++] = 'K';
                ms[j++] = '_';
                break;

            default:
                ms[j++] = s[i];
        }
    }
    ms[new_len] = '\0';

    return ms;
}

JSValueRef get_value_on_object(JSContextRef ctx, JSObjectRef obj, char *name) {
    JSStringRef name_str = JSStringCreateWithUTF8CString(name);
    JSValueRef val = JSObjectGetProperty(ctx, obj, name_str, NULL);
    JSStringRelease(name_str);
    return val;
}

JSValueRef get_value(JSContextRef ctx, char *namespace, char *name) {
    JSValueRef ns_val = NULL;

        // printf("get_value: '%s'\n", namespace);
    char *ns_tmp = strdup(namespace);
    char *saveptr;
    char *ns_part = strtok_r(ns_tmp, ".", &saveptr);
    while (ns_part != NULL) {
        char *munged_ns_part = munge(ns_part);
        if (ns_val) {
            ns_val = get_value_on_object(ctx, JSValueToObject(ctx, ns_val, NULL), munged_ns_part);
        } else {
            ns_val = get_value_on_object(ctx, JSContextGetGlobalObject(ctx), munged_ns_part);
        }
        free(munged_ns_part); // TODO: Use a fixed buffer for this?  (Which would restrict namespace part length...)

        ns_part = strtok_r(NULL, ".", &saveptr);
    }
    free(ns_tmp);

    char *munged_name = munge(name);
    JSValueRef val = get_value_on_object(ctx, JSValueToObject(ctx, ns_val, NULL), munged_name);
    free(munged_name);
    return val;
}

JSObjectRef get_function(char *namespace, char *name) {
    JSValueRef val = get_value(ctx, namespace, name);
    if (JSValueIsUndefined(ctx, val)) {
        char buffer[1024];
        snprintf(buffer, 1024, "Failed to get function %s/%s\n", namespace, name);
            //engine_print(buffer);
        assert(false);
    }
    return JSValueToObject(ctx, val, NULL);
}

typedef void (*timer_callback_t)(void *data);

struct timer_data_t {
    long millis;
    timer_callback_t timer_callback;
    void *data;
};

void *timer_thread(void *data) {

    struct timer_data_t *timer_data = data;

    struct timespec t;
    t.tv_sec = timer_data->millis / 1000;
    t.tv_nsec = 1000 * 1000 * (timer_data->millis % 1000);
    if (t.tv_sec == 0 && t.tv_nsec == 0) {
        t.tv_nsec = 1; /* Evidently needed on Ubuntu 14.04 */
    }

    int err = nanosleep(&t, NULL);
    if (err) {
        free(data);
            //engine_perror("timer nanosleep");
        return NULL;
    }

    timer_data->timer_callback(timer_data->data);

    free(data);

    return NULL;
}

int start_timer(long millis, timer_callback_t timer_callback, void *data) {

    struct timer_data_t *timer_data = malloc(sizeof(struct timer_data_t));
    if (!timer_data) return -1;

    timer_data->millis = millis;
    timer_data->timer_callback = timer_callback;
    timer_data->data = data;

    pthread_attr_t attr;
    int err = pthread_attr_init(&attr);
    if (err) {
        free(timer_data);
        return err;
    }

    err = pthread_attr_setdetachstate(&attr, PTHREAD_CREATE_DETACHED);
    if (err) {
        free(timer_data);
        return err;
    }

    pthread_t thread;
    err = pthread_create(&thread, &attr, timer_thread, timer_data);
    if (err) {
        free(timer_data);
    }
    return err;
}

void do_run_timeout(void *data) {

    unsigned long *timeout_data = data;

    JSValueRef args[1];
    args[0] = JSValueMakeNumber(ctx, (double)*timeout_data);
    free(timeout_data);

    static JSObjectRef run_timeout_fn = NULL;
    if (!run_timeout_fn) {
        run_timeout_fn = get_function("global", "REPLETE_RUN_TIMEOUT");
        JSValueProtect(ctx, run_timeout_fn);
    }
    acquire_eval_lock();
    JSObjectCallAsFunction(ctx, run_timeout_fn, NULL, 1, args, NULL);
    release_eval_lock();
}

static unsigned long timeout_id = 0;

JSValueRef function_set_timeout(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject,
                                size_t argc, const JSValueRef args[], JSValueRef *exception) {
    if (argc == 1
        && JSValueGetType(ctx, args[0]) == kJSTypeNumber) {

        int millis = (int) JSValueToNumber(ctx, args[0], NULL);

        if (timeout_id == 9007199254740991) {
            timeout_id = 0;
        } else {
            ++timeout_id;
        }

        JSValueRef rv = JSValueMakeNumber(ctx, (double)timeout_id);

        unsigned long *timeout_data = malloc(sizeof(unsigned long));
        *timeout_data = timeout_id;

        start_timer(millis, do_run_timeout, (void *) timeout_data);

        return rv;
    }
    return JSValueMakeNull(ctx);
}

void do_run_interval(void *data) {

    unsigned long *interval_data = data;

    JSValueRef args[1];
    args[0] = JSValueMakeNumber(ctx, (double)*interval_data);
    free(interval_data);

    static JSObjectRef run_interval_fn = NULL;
    if (!run_interval_fn) {
        run_interval_fn = get_function("global", "REPLETE_RUN_INTERVAL");
        JSValueProtect(ctx, run_interval_fn);
    }
    acquire_eval_lock();
    JSObjectCallAsFunction(ctx, run_interval_fn, NULL, 1, args, NULL);
    release_eval_lock();
}

static unsigned long interval_id = 0;

JSValueRef function_set_interval(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject,
                                 size_t argc, const JSValueRef args[], JSValueRef *exception) {
    if (argc == 2
        && JSValueGetType(ctx, args[0]) == kJSTypeNumber) {

        int millis = (int) JSValueToNumber(ctx, args[0], NULL);

        unsigned long curr_interval_id;

        if (JSValueIsNull(ctx, args[1])) {
            if (interval_id == 9007199254740991) {
                interval_id = 0;
            } else {
                ++interval_id;
            }
            curr_interval_id = interval_id;
        } else {
            curr_interval_id = (unsigned long) JSValueToNumber(ctx, args[1], NULL);
        }

        JSValueRef rv = JSValueMakeNumber(ctx, (double)curr_interval_id);

        unsigned long *interval_data = malloc(sizeof(unsigned long));
        *interval_data = curr_interval_id;

        start_timer(millis, do_run_interval, (void *) interval_data);

        return rv;
    }
    return JSValueMakeNull(ctx);
}


void bootstrap(JSContextRef ctx) {

    char *deps_file_path = "main.js";
    char *goog_base_path = "goog/base.js";

    char source[] = "<bootstrap>";

        // Setup CLOSURE_IMPORT_SCRIPT
    evaluate_script(ctx, "CLOSURE_IMPORT_SCRIPT = function(src) { AMBLY_IMPORT_SCRIPT('goog/' + src); return true; }",
                    source);

        // Load goog base
    char *base_script_str = bundle_get_contents(goog_base_path);
    if (base_script_str == NULL) {
        fprintf(stderr, "The goog base JavaScript text could not be loaded\n");
        exit(1);
    }
    evaluate_script(ctx, base_script_str, "<bootstrap:base>");
    free(base_script_str);

        // Load the deps file
    char *deps_script_str = bundle_get_contents(deps_file_path);
    if (deps_script_str == NULL) {
        fprintf(stderr, "The deps JavaScript text could not be loaded\n");
        exit(1);
    }
    evaluate_script(ctx, deps_script_str, "<bootstrap:deps>");
    free(deps_script_str);

    evaluate_script(ctx, "goog.isProvided_ = function(x) { return false; };", source);

    evaluate_script(ctx,
                    "goog.require = function (name) { return CLOSURE_IMPORT_SCRIPT(goog.dependencies_.nameToPath[name]); };",
                    source);

    evaluate_script(ctx, "goog.require('cljs.core');", source);

        // redef goog.require to track loaded libs
    evaluate_script(ctx,
                    "cljs.core._STAR_loaded_libs_STAR_ = cljs.core.into.call(null, cljs.core.PersistentHashSet.EMPTY, [\"cljs.core\"]);\n"
                    "goog.require = function (name, reload) {\n"
                    "    if(!cljs.core.contains_QMARK_(cljs.core._STAR_loaded_libs_STAR_, name) || reload) {\n"
                    "        var AMBLY_TMP = cljs.core.PersistentHashSet.EMPTY;\n"
                    "        if (cljs.core._STAR_loaded_libs_STAR_) {\n"
                    "            AMBLY_TMP = cljs.core._STAR_loaded_libs_STAR_;\n"
                    "        }\n"
                    "        cljs.core._STAR_loaded_libs_STAR_ = cljs.core.into.call(null, AMBLY_TMP, [name]);\n"
                    "        CLOSURE_IMPORT_SCRIPT(goog.dependencies_.nameToPath[name]);\n"
                    "    }\n"
                    "};", source);

    register_global_function(ctx, "REPLETE_SET_TIMEOUT", function_set_timeout);
    register_global_function(ctx, "REPLETE_SET_INTERVAL", function_set_interval);
    evaluate_script(ctx,
                    "var REPLETE_TIMEOUT_CALLBACK_STORE = {};\
                    var setTimeout = function( fn, ms ) {\
                    var id = REPLETE_SET_TIMEOUT(ms);\
                    REPLETE_TIMEOUT_CALLBACK_STORE[id] = fn;\
                    return id;\
                    };\
                    var REPLETE_RUN_TIMEOUT = function( id ) {\
                    if( REPLETE_TIMEOUT_CALLBACK_STORE[id] ) {\
                    REPLETE_TIMEOUT_CALLBACK_STORE[id]();\
                    delete REPLETE_TIMEOUT_CALLBACK_STORE[id];\
                    }\
                    };\
                    var clearTimeout = function( id ) {\
                    delete REPLETE_TIMEOUT_CALLBACK_STORE[id];\
                    };\
                    var REPLETE_INTERVAL_CALLBACK_STORE = {};\
                    var setInterval = function( fn, ms ) {\
                    var id = REPLETE_SET_INTERVAL(ms, null);\
                    REPLETE_INTERVAL_CALLBACK_STORE[id] = \
                    function(){ fn(); REPLETE_SET_INTERVAL(ms, id); };\
                    return id;\
                    };\
                    var REPLETE_RUN_INTERVAL = function( id ) {\
                    if( REPLETE_INTERVAL_CALLBACK_STORE[id] ) {\
                    REPLETE_INTERVAL_CALLBACK_STORE[id]();\
                    }\
                    };\
                    var clearInterval = function( id ) {\
                    delete REPLETE_INTERVAL_CALLBACK_STORE[id];\
                    };",
                    "<init>");

    register_global_function(ctx, "REPLETE_READ_FILE", function_read_file);

    register_global_function(ctx, "REPLETE_EVAL", function_eval);

    register_global_function(ctx, "REPLETE_RAW_WRITE_STDOUT", function_raw_write_stdout);
    register_global_function(ctx, "REPLETE_RAW_FLUSH_STDOUT", function_raw_flush_stdout);
    register_global_function(ctx, "REPLETE_RAW_WRITE_STDERR", function_raw_write_stderr);
    register_global_function(ctx, "REPLETE_RAW_FLUSH_STDERR", function_raw_flush_stderr);

    register_global_function(ctx, "REPLETE_FILE_READER_OPEN", function_file_reader_open);
    register_global_function(ctx, "REPLETE_FILE_READER_READ", function_file_reader_read);
    register_global_function(ctx, "REPLETE_FILE_READER_CLOSE", function_file_reader_close);

    register_global_function(ctx, "REPLETE_FILE_WRITER_OPEN", function_file_writer_open);
    register_global_function(ctx, "REPLETE_FILE_WRITER_WRITE", function_file_writer_write);
    register_global_function(ctx, "REPLETE_FILE_WRITER_FLUSH", function_file_writer_flush);
    register_global_function(ctx, "REPLETE_FILE_WRITER_CLOSE", function_file_writer_close);

    register_global_function(ctx, "REPLETE_FILE_INPUT_STREAM_OPEN", function_file_input_stream_open);
    register_global_function(ctx, "REPLETE_FILE_INPUT_STREAM_READ", function_file_input_stream_read);
    register_global_function(ctx, "REPLETE_FILE_INPUT_STREAM_CLOSE", function_file_input_stream_close);

    register_global_function(ctx, "REPLETE_FILE_OUTPUT_STREAM_OPEN", function_file_output_stream_open);
    register_global_function(ctx, "REPLETE_FILE_OUTPUT_STREAM_WRITE", function_file_output_stream_write);
    register_global_function(ctx, "REPLETE_FILE_OUTPUT_STREAM_FLUSH", function_file_output_stream_flush);
    register_global_function(ctx, "REPLETE_FILE_OUTPUT_STREAM_CLOSE", function_file_output_stream_close);

    register_global_function(ctx, "REPLETE_MKDIRS", function_mkdirs);
    register_global_function(ctx, "REPLETE_DELETE", function_delete_file);
    register_global_function(ctx, "REPLETE_COPY", function_copy_file);

    register_global_function(ctx, "REPLETE_LIST_FILES", function_list_files);

    register_global_function(ctx, "REPLETE_IS_DIRECTORY", function_is_directory);

    register_global_function(ctx, "REPLETE_FSTAT", function_fstat);

    register_global_function(ctx, "REPLETE_REQUEST", function_http_request);

    register_global_function(ctx, "REPLETE_SLEEP", function_sleep);

}
#endif


