; ModuleID = 'main'
source_filename = "main.hike"
target triple = "x86_64-w64-windows-gnu"

; ==============================================================================
; Hike Language Builtin Runtime (LLVM IR)
; ==============================================================================

; ------------------------------------------------------------------------------
; External C Standard Library Declarations
; ------------------------------------------------------------------------------
declare noalias i8* @malloc(i64)
declare noalias i8* @calloc(i64, i64)
declare void @free(i8*)
declare i8* @fopen(i8*, i8*)
declare i64 @fwrite(i8*, i64, i64, i8*)
declare i64 @fread(i8*, i64, i64, i8*)
declare i32 @fclose(i8*)
declare i64 @fseek(i8*, i64, i64)
declare i64 @_ftelli64(i8*)

@__hike_mapped_write_mode = private unnamed_addr constant [3 x i8] c"wb\00"
@__hike_mapped_read_mode = private unnamed_addr constant [3 x i8] c"rb\00"
@__hike_mapped_append_mode = private unnamed_addr constant [3 x i8] c"ab\00"
@__hike_mapped_update_mode = private unnamed_addr constant [4 x i8] c"rb+\00"
@__hike_mapped_magic = private unnamed_addr constant [4 x i8] c"HMB3"

define internal i32 @__hike_mapped_graph_save(i8* %path_ptr, i8* %data, i64 %size, i8* %relocations, i64 %relocation_count, i64 %schema_hash) {
entry:
  %mode_ptr = getelementptr inbounds [3 x i8], [3 x i8]* @__hike_mapped_write_mode, i32 0, i32 0
  %file = call i8* @fopen(i8* %path_ptr, i8* %mode_ptr)
  %missing = icmp eq i8* %file, null
  br i1 %missing, label %fail, label %write
write:
  %header = alloca [64 x i8], align 8
  %header_bytes = bitcast [64 x i8]* %header to i8*
  %magic = getelementptr inbounds [4 x i8], [4 x i8]* @__hike_mapped_magic, i32 0, i32 0
  call i8* @memcpy(i8* %header_bytes, i8* %magic, i64 4)
  %version_ptr = getelementptr inbounds i8, i8* %header_bytes, i64 4
  %version = bitcast i8* %version_ptr to i32*
  store i32 3, i32* %version, align 1
  %root_ptr = getelementptr inbounds i8, i8* %header_bytes, i64 8
  %root = bitcast i8* %root_ptr to i64*
  store i64 %size, i64* %root, align 1
  %schema_ptr = getelementptr inbounds i8, i8* %header_bytes, i64 40
  %schema = bitcast i8* %schema_ptr to i64*
  store i64 %schema_hash, i64* %schema, align 1
  %written_header = call i64 @fwrite(i8* %header_bytes, i64 1, i64 64, i8* %file)
  %written_data = call i64 @fwrite(i8* %data, i64 1, i64 %size, i8* %file)
  %closed = call i32 @fclose(i8* %file)
  %header_ok = icmp eq i64 %written_header, 64
  %data_ok = icmp eq i64 %written_data, %size
  %close_ok = icmp eq i32 %closed, 0
  %ok0 = and i1 %header_ok, %data_ok
  %ok = and i1 %ok0, %close_ok
  %result = zext i1 %ok to i32
  ret i32 %result
fail:
  ret i32 0
}

define internal i32 @__hike_mapped_graph_finalize(i8* %path_ptr, i64 %root_size, i64 %schema_hash) {
entry:
  %mode_ptr = getelementptr inbounds [4 x i8], [4 x i8]* @__hike_mapped_update_mode, i32 0, i32 0
  %file = call i8* @fopen(i8* %path_ptr, i8* %mode_ptr)
  %missing = icmp eq i8* %file, null
  br i1 %missing, label %fail, label %measure
measure:
  %end_result = call i64 @fseek(i8* %file, i64 0, i64 2)
  %file_size = call i64 @_ftelli64(i8* %file)
  %payload_start = add i64 %root_size, 64
  %payload_size = sub i64 %file_size, %payload_start
  %header = alloca [64 x i8], align 8
  %header_bytes = bitcast [64 x i8]* %header to i8*
  %magic = getelementptr inbounds [4 x i8], [4 x i8]* @__hike_mapped_magic, i32 0, i32 0
  call i8* @memcpy(i8* %header_bytes, i8* %magic, i64 4)
  %version_ptr = getelementptr inbounds i8, i8* %header_bytes, i64 4
  %version = bitcast i8* %version_ptr to i32*
  store i32 3, i32* %version, align 1
  %root_ptr = getelementptr inbounds i8, i8* %header_bytes, i64 8
  %root = bitcast i8* %root_ptr to i64*
  store i64 %root_size, i64* %root, align 1
  %heap_ptr = getelementptr inbounds i8, i8* %header_bytes, i64 16
  %heap = bitcast i8* %heap_ptr to i64*
  store i64 %payload_size, i64* %heap, align 1
  %payload_ptr = getelementptr inbounds i8, i8* %header_bytes, i64 32
  %payload = bitcast i8* %payload_ptr to i64*
  store i64 %payload_size, i64* %payload, align 1
  %schema_ptr = getelementptr inbounds i8, i8* %header_bytes, i64 40
  %schema = bitcast i8* %schema_ptr to i64*
  store i64 %schema_hash, i64* %schema, align 1
  %relocation_ptr = getelementptr inbounds i8, i8* %header_bytes, i64 48
  %relocation = bitcast i8* %relocation_ptr to i64*
  store i64 %file_size, i64* %relocation, align 1
  %relocation_bytes_ptr = getelementptr inbounds i8, i8* %header_bytes, i64 56
  %relocation_bytes = bitcast i8* %relocation_bytes_ptr to i64*
  store i64 0, i64* %relocation_bytes, align 1
  %rewrite = call i64 @fseek(i8* %file, i64 0, i64 0)
  %written = call i64 @fwrite(i8* %header_bytes, i64 1, i64 64, i8* %file)
  %closed = call i32 @fclose(i8* %file)
  %write_ok = icmp eq i64 %written, 64
  %close_ok = icmp eq i32 %closed, 0
  %ok = and i1 %write_ok, %close_ok
  %result = zext i1 %ok to i32
  ret i32 %result
fail:
  ret i32 0
}

define internal i32 @__hike_mapped_graph_load(i8* %path_ptr, i8* %data, i64 %size, i8* %relocations, i64 %relocation_count, i64 %schema_hash) {
entry:
  %mode_ptr = getelementptr inbounds [3 x i8], [3 x i8]* @__hike_mapped_read_mode, i32 0, i32 0
  %file = call i8* @fopen(i8* %path_ptr, i8* %mode_ptr)
  %missing = icmp eq i8* %file, null
  br i1 %missing, label %fail, label %read_header
read_header:
  %header = alloca [64 x i8], align 8
  %header_bytes = bitcast [64 x i8]* %header to i8*
  %read_header_bytes = call i64 @fread(i8* %header_bytes, i64 1, i64 64, i8* %file)
  %magic = getelementptr inbounds [4 x i8], [4 x i8]* @__hike_mapped_magic, i32 0, i32 0
  %magic_cmp = call i32 @memcmp(i8* %header_bytes, i8* %magic, i64 4)
  %magic_ok = icmp eq i32 %magic_cmp, 0
  %version_ptr = getelementptr inbounds i8, i8* %header_bytes, i64 4
  %version = bitcast i8* %version_ptr to i32*
  %version_value = load i32, i32* %version, align 1
  %version_ok = icmp eq i32 %version_value, 3
  %root_ptr = getelementptr inbounds i8, i8* %header_bytes, i64 8
  %root = bitcast i8* %root_ptr to i64*
  %root_value = load i64, i64* %root, align 1
  %root_ok = icmp eq i64 %root_value, %size
  %schema_ptr = getelementptr inbounds i8, i8* %header_bytes, i64 40
  %schema = bitcast i8* %schema_ptr to i64*
  %schema_value = load i64, i64* %schema, align 1
  %schema_ok = icmp eq i64 %schema_value, %schema_hash
  %header_ok0 = icmp eq i64 %read_header_bytes, 64
  %header_ok1 = and i1 %header_ok0, %magic_ok
  %header_ok2 = and i1 %header_ok1, %version_ok
  %header_ok3 = and i1 %header_ok2, %root_ok
  %header_ok = and i1 %header_ok3, %schema_ok
  br i1 %header_ok, label %read_data, label %close_fail
read_data:
  %read = call i64 @fread(i8* %data, i64 1, i64 %size, i8* %file)
  %closed = call i32 @fclose(i8* %file)
  %read_ok = icmp eq i64 %read, %size
  %close_ok = icmp eq i32 %closed, 0
  %ok = and i1 %read_ok, %close_ok
  %result = zext i1 %ok to i32
  ret i32 %result
close_fail:
  call i32 @fclose(i8* %file)
  br label %fail
fail:
  ret i32 0
}

; Mapped strings and slices are stored as payload bytes after the fixed image.
; The fixed image keeps the payload offset and length, never a process-local
; pointer or reference counter.
define internal i32 @__hike_mapped_string_append(i8* %path_ptr, i8* %data, i32 %len) {
entry:
  %mode_ptr = getelementptr inbounds [3 x i8], [3 x i8]* @__hike_mapped_append_mode, i32 0, i32 0
  %file = call i8* @fopen(i8* %path_ptr, i8* %mode_ptr)
  %missing = icmp eq i8* %file, null
  br i1 %missing, label %fail, label %write
write:
  %len64 = zext i32 %len to i64
  %written = call i64 @fwrite(i8* %data, i64 1, i64 %len64, i8* %file)
  %closed = call i32 @fclose(i8* %file)
  %ok = icmp eq i64 %written, %len64
  %ok2 = icmp eq i32 %closed, 0
  %result = and i1 %ok, %ok2
  %result32 = zext i1 %result to i32
  ret i32 %result32
fail:
  ret i32 0
}

define internal { i8*, i32, i32 } @__hike_mapped_string_load(i8* %path_ptr, i32 %file_offset, i32 %len) {
entry:
  %mode_ptr = getelementptr inbounds [3 x i8], [3 x i8]* @__hike_mapped_read_mode, i32 0, i32 0
  %file = call i8* @fopen(i8* %path_ptr, i8* %mode_ptr)
  %missing = icmp eq i8* %file, null
  br i1 %missing, label %fail, label %seek
seek:
  %file_offset64 = sext i32 %file_offset to i64
  %mapped_offset = add i64 %file_offset64, 64
  %seek_result = call i64 @fseek(i8* %file, i64 %mapped_offset, i64 0)
  %seek_failed = icmp ne i64 %seek_result, 0
  br i1 %seek_failed, label %close_fail, label %allocate
allocate:
  %len64 = zext i32 %len to i64
  %alloc_size = add i64 %len64, 9
  %raw = call i8* @malloc(i64 %alloc_size)
  %cap_ptr = bitcast i8* %raw to i32*
  store i32 %len, i32* %cap_ptr
  %ref_ptr = getelementptr inbounds i8, i8* %raw, i64 4
  %ref32 = bitcast i8* %ref_ptr to i32*
  store i32 1, i32* %ref32
  %data = getelementptr inbounds i8, i8* %raw, i64 8
  %read = call i64 @fread(i8* %data, i64 1, i64 %len64, i8* %file)
  %closed = call i32 @fclose(i8* %file)
  %read_ok = icmp eq i64 %read, %len64
  %close_ok = icmp eq i32 %closed, 0
  %ok = and i1 %read_ok, %close_ok
  br i1 %ok, label %success, label %free_fail
success:
  %value0 = insertvalue { i8*, i32, i32 } undef, i8* %data, 0
  %value1 = insertvalue { i8*, i32, i32 } %value0, i32 0, 1
  %value2 = insertvalue { i8*, i32, i32 } %value1, i32 %len, 2
  ret { i8*, i32, i32 } %value2
free_fail:
  call void @free(i8* %raw)
  ret { i8*, i32, i32 } zeroinitializer
close_fail:
  call i32 @fclose(i8* %file)
  br label %fail
fail:
  ret { i8*, i32, i32 } zeroinitializer
}

define internal i8* @__hike_mapped_slice_load(i8* %path_ptr, i32 %file_offset, i32 %len, i64 %elem_size) {
entry:
  %mode_ptr = getelementptr inbounds [3 x i8], [3 x i8]* @__hike_mapped_read_mode, i32 0, i32 0
  %file = call i8* @fopen(i8* %path_ptr, i8* %mode_ptr)
  %missing = icmp eq i8* %file, null
  br i1 %missing, label %fail, label %seek
seek:
  %file_offset64 = sext i32 %file_offset to i64
  %mapped_offset = add i64 %file_offset64, 64
  %seek_result = call i64 @fseek(i8* %file, i64 %mapped_offset, i64 0)
  %seek_failed = icmp ne i64 %seek_result, 0
  br i1 %seek_failed, label %close_fail, label %allocate
allocate:
  %len64 = zext i32 %len to i64
  %bytes = mul i64 %len64, %elem_size
  %owner = call i8* @__hike_slice_alloc(i64 %bytes, i64 %len64)
  %read = call i64 @fread(i8* %owner, i64 1, i64 %bytes, i8* %file)
  %closed = call i32 @fclose(i8* %file)
  %read_ok = icmp eq i64 %read, %bytes
  %close_ok = icmp eq i32 %closed, 0
  %ok = and i1 %read_ok, %close_ok
  br i1 %ok, label %success, label %free_fail
success:
  ret i8* %owner
free_fail:
  %raw = getelementptr inbounds i8, i8* %owner, i64 -16
  call void @free(i8* %raw)
  ret i8* null
close_fail:
  call i32 @fclose(i8* %file)
  br label %fail
fail:
  ret i8* null
}

; cbuffer is an explicitly-owned foreign buffer. It has no Hike-side
; reference count: {data, length, hike_func_value, closed}.
; The release callback is a Hike func() value: {code pointer, environment}.
define internal { i8*, i64, { i8*, i8* }, i1 } @__hike_cbuffer_new(i8* %data, i64 %length, { i8*, i8* } %release) #0 {
entry:
  %zero = insertvalue { i8*, i64, { i8*, i8* }, i1 } zeroinitializer, i8* %data, 0
  %with_len = insertvalue { i8*, i64, { i8*, i8* }, i1 } %zero, i64 %length, 1
  %with_release = insertvalue { i8*, i64, { i8*, i8* }, i1 } %with_len, { i8*, i8* } %release, 2
  %result = insertvalue { i8*, i64, { i8*, i8* }, i1 } %with_release, i1 false, 3
  ret { i8*, i64, { i8*, i8* }, i1 } %result
}

define internal void @__hike_cbuffer_close({ i8*, i64, { i8*, i8* }, i1 }* %buffer) #0 {
entry:
  %current = load { i8*, i64, { i8*, i8* }, i1 }, { i8*, i64, { i8*, i8* }, i1 }* %buffer
  %closed = extractvalue { i8*, i64, { i8*, i8* }, i1 } %current, 3
  br i1 %closed, label %done, label %release
release:
  %data = extractvalue { i8*, i64, { i8*, i8* }, i1 } %current, 0
  %release_value = extractvalue { i8*, i64, { i8*, i8* }, i1 } %current, 2
  %release_code = extractvalue { i8*, i8* } %release_value, 0
  %release_env = extractvalue { i8*, i8* } %release_value, 1
  %has_release = icmp ne i8* %release_code, null
  br i1 %has_release, label %call_release, label %default_free
call_release:
  %is_plain = icmp eq i8* %release_env, null
  br i1 %is_plain, label %call_plain, label %call_closure
call_plain:
  %plain_fn = bitcast i8* %release_code to void ()*
  call void %plain_fn()
  br label %mark_closed
call_closure:
  %closure_fn = bitcast i8* %release_code to void (i8*)*
  call void %closure_fn(i8* %release_env)
  br label %mark_closed
default_free:
  call void @free(i8* %data)
  br label %mark_closed
mark_closed:
  %closed_value = insertvalue { i8*, i64, { i8*, i8* }, i1 } %current, i1 true, 3
  store { i8*, i64, { i8*, i8* }, i1 } %closed_value, { i8*, i64, { i8*, i8* }, i1 }* %buffer
  br label %done
done:
  ret void
}

define internal i64 @__hike_cbuffer_length({ i8*, i64, { i8*, i8* }, i1 }* %buffer) #0 {
entry:
  %current = load { i8*, i64, { i8*, i8* }, i1 }, { i8*, i64, { i8*, i8* }, i1 }* %buffer
  %closed = extractvalue { i8*, i64, { i8*, i8* }, i1 } %current, 3
  br i1 %closed, label %zero, label %read
zero:
  ret i64 0
read:
  %length = extractvalue { i8*, i64, { i8*, i8* }, i1 } %current, 1
  ret i64 %length
}

define internal i8* @__hike_cbuffer_data({ i8*, i64, { i8*, i8* }, i1 }* %buffer) #0 {
entry:
  %current = load { i8*, i64, { i8*, i8* }, i1 }, { i8*, i64, { i8*, i8* }, i1 }* %buffer
  %closed = extractvalue { i8*, i64, { i8*, i8* }, i1 } %current, 3
  br i1 %closed, label %zero, label %read
zero:
  ret i8* null
read:
  %data = extractvalue { i8*, i64, { i8*, i8* }, i1 } %current, 0
  ret i8* %data
}

; Copy a cbuffer range into a normal, Hike-owned []byte slice. The cbuffer
; itself is never retained by this operation.
define internal { i8*, i32, i32 } @__hike_cbuffer_slice({ i8*, i64, { i8*, i8* }, i1 }* %buffer, i64 %low, i64 %high) #0 {
entry:
  %current = load { i8*, i64, { i8*, i8* }, i1 }, { i8*, i64, { i8*, i8* }, i1 }* %buffer
  %closed = extractvalue { i8*, i64, { i8*, i8* }, i1 } %current, 3
  br i1 %closed, label %empty, label %check
check:
  %data = extractvalue { i8*, i64, { i8*, i8* }, i1 } %current, 0
  %length = extractvalue { i8*, i64, { i8*, i8* }, i1 } %current, 1
  %valid_high = icmp ule i64 %high, %length
  %valid_low = icmp ule i64 %low, %high
  %valid = and i1 %valid_high, %valid_low
  br i1 %valid, label %copy, label %empty
copy:
  %count = sub i64 %high, %low
  %total = add i64 %count, 16
  %raw = call i8* @calloc(i64 1, i64 %total)
  %cap_ptr = bitcast i8* %raw to i32*
  %cap32 = trunc i64 %count to i32
  store i32 %cap32, i32* %cap_ptr
  %ref_raw = getelementptr inbounds i8, i8* %raw, i64 4
  %ref_ptr = bitcast i8* %ref_raw to i32*
  store i32 1, i32* %ref_ptr
  %destination = getelementptr inbounds i8, i8* %raw, i64 16
  %source = getelementptr inbounds i8, i8* %data, i64 %low
  call i8* @memcpy(i8* %destination, i8* %source, i64 %count)
  %result0 = insertvalue { i8*, i32, i32 } zeroinitializer, i8* %destination, 0
  %result1 = insertvalue { i8*, i32, i32 } %result0, i32 0, 1
  %result2 = insertvalue { i8*, i32, i32 } %result1, i32 %cap32, 2
  ret { i8*, i32, i32 } %result2
empty:
  ret { i8*, i32, i32 } zeroinitializer
}

; Slice backing storage. The returned pointer addresses the first payload byte;
; capacity is stored as i32 at owner-16. calloc keeps make([]T,n) zeroed while
; giving all slice allocation paths one header layout.
define internal i8* @__hike_slice_alloc(i64 %size, i64 %capacity) #0 {
entry:
  %total = add i64 %size, 16
  %raw = call i8* @calloc(i64 1, i64 %total)
  %cap_ptr = bitcast i8* %raw to i32*
  %cap32 = trunc i64 %capacity to i32
  store i32 %cap32, i32* %cap_ptr
  %ref_raw = getelementptr inbounds i8, i8* %raw, i64 4
  %ref_ptr = bitcast i8* %ref_raw to i32*
  store i32 1, i32* %ref_ptr
  %owner = getelementptr inbounds i8, i8* %raw, i64 16
  ret i8* %owner
}

define internal i64 @__hike_slice_cap(i8* %owner) #0 {
entry:
  %is_null = icmp eq i8* %owner, null
  br i1 %is_null, label %zero, label %load
zero:
  ret i64 0
load:
  %raw = getelementptr inbounds i8, i8* %owner, i64 -16
  %cap_ptr = bitcast i8* %raw to i32*
  %cap32 = load i32, i32* %cap_ptr
  %cap = zext i32 %cap32 to i64
  ret i64 %cap
}

define internal void @__hike_slice_retain(i8* %owner, i32 %offset) #0 {
entry:
  %is_null = icmp eq i8* %owner, null
  %literal = icmp slt i32 %offset, 0
  %skip = or i1 %is_null, %literal
  br i1 %skip, label %done, label %load
load:
  %raw = getelementptr inbounds i8, i8* %owner, i64 -12
  %ref_ptr = bitcast i8* %raw to i32*
  %old = load i32, i32* %ref_ptr
  %immortal = icmp eq i32 %old, -2147483648
  br i1 %immortal, label %done, label %increment
increment:
  %next = add i32 %old, 1
  store i32 %next, i32* %ref_ptr
  br label %done
done:
  ret void
}

define internal void @__hike_slice_release(i8* %owner, i32 %offset) #0 {
entry:
  %is_null = icmp eq i8* %owner, null
  %literal = icmp slt i32 %offset, 0
  %skip = or i1 %is_null, %literal
  br i1 %skip, label %done, label %load
load:
  %raw = getelementptr inbounds i8, i8* %owner, i64 -12
  %ref_ptr = bitcast i8* %raw to i32*
  %old = load i32, i32* %ref_ptr
  %immortal = icmp eq i32 %old, -2147483648
  br i1 %immortal, label %done, label %check_free
check_free:
  %last = icmp eq i32 %old, 1
  br i1 %last, label %free_buffer, label %decrement
decrement:
  %next = sub i32 %old, 1
  store i32 %next, i32* %ref_ptr
  br label %done
free_buffer:
  %allocation = getelementptr inbounds i8, i8* %owner, i64 -16
  call void @free(i8* %allocation)
  br label %done
done:
  ret void
}

@__hike_region_active_stat = internal global i64 0
@__hike_region_begin_count_stat = internal global i64 0
@__hike_region_end_count_stat = internal global i64 0
@__hike_region_allocated_bytes_stat = internal global i64 0
@__hike_region_released_bytes_stat = internal global i64 0
@__hike_panic_value = internal global { i32, i8* } zeroinitializer
@__hike_panic_cause_state = internal global { i32, i8* } zeroinitializer
@__hike_panic_site_state = internal global i32 -1
@__hike_panic_active = internal global i1 false
@__hike_lock_state = internal global i32 0

define internal void @__hike_lock() {
entry:
  br label %retry
retry:
  %attempt = cmpxchg i32* @__hike_lock_state, i32 0, i32 1 acquire acquire
  %acquired = extractvalue { i32, i1 } %attempt, 1
  br i1 %acquired, label %done, label %retry
done:
  ret void
}
define internal void @__hike_unlock() {
entry:
  store atomic i32 0, i32* @__hike_lock_state release, align 4
  ret void
}

declare void @llvm.trap()

define internal void @__hike_panic_set({ i32, i8* } %value, { i32, i8* } %cause, i32 %site) {
entry:
  store { i32, i8* } %value, { i32, i8* }* @__hike_panic_value
  store { i32, i8* } %cause, { i32, i8* }* @__hike_panic_cause_state
  store i32 %site, i32* @__hike_panic_site_state
  store i1 true, i1* @__hike_panic_active
  ret void
}
define internal { i32, i8* } @__hike_panic_get() {
entry:
  %value = load { i32, i8* }, { i32, i8* }* @__hike_panic_value
  store i1 false, i1* @__hike_panic_active
  ret { i32, i8* } %value
}
define internal { i32, i8* } @__hike_panic_cause() {
entry:
  %cause = load { i32, i8* }, { i32, i8* }* @__hike_panic_cause_state
  ret { i32, i8* } %cause
}
define internal i32 @__hike_panic_site() {
entry:
  %site = load i32, i32* @__hike_panic_site_state
  ret i32 %site
}
define internal i1 @__hike_panic_is_active() {
entry:
  %active = load i1, i1* @__hike_panic_active
  ret i1 %active
}
define internal void @__hike_panic_fatal(i32 %site) {
entry:
  %panic = load { i32, i8* }, { i32, i8* }* @__hike_panic_value
  %data = extractvalue { i32, i8* } %panic, 1
  %string = bitcast i8* %data to { i8*, i32, i32 }*
  %base_ptr = getelementptr { i8*, i32, i32 }, { i8*, i32, i32 }* %string, i32 0, i32 0
  %offset_ptr = getelementptr { i8*, i32, i32 }, { i8*, i32, i32 }* %string, i32 0, i32 1
  %length_ptr = getelementptr { i8*, i32, i32 }, { i8*, i32, i32 }* %string, i32 0, i32 2
  %base = load i8*, i8** %base_ptr
  %offset = load i32, i32* %offset_ptr
  %length = load i32, i32* %length_ptr
  %start = call i8* @__hike_string_start(i8* %base, i32 %offset)
  call void @__hike_stderr_write(i8* %start, i32 %length)
  call void @llvm.trap()
  unreachable
}
define internal i64 @__hike_region_active_count() {
entry:
  %v = load i64, i64* @__hike_region_active_stat
  ret i64 %v
}
define internal i64 @__hike_region_begin_count() {
entry:
  %v = load i64, i64* @__hike_region_begin_count_stat
  ret i64 %v
}
define internal i64 @__hike_region_end_count() {
entry:
  %v = load i64, i64* @__hike_region_end_count_stat
  ret i64 %v
}
define internal i64 @__hike_region_allocated_bytes() {
entry:
  %v = load i64, i64* @__hike_region_allocated_bytes_stat
  ret i64 %v
}
define internal i64 @__hike_region_released_bytes() {
entry:
  %v = load i64, i64* @__hike_region_released_bytes_stat
  ret i64 %v
}

; Per-function bump arena. The single end call releases the arena in O(1).
%struct.__hike_region = type { i8*, i64, i64 }
define internal i8* @__hike_region_begin() {
entry:
  %bc = load i64, i64* @__hike_region_begin_count_stat
  %bc1 = add i64 %bc, 1
  store i64 %bc1, i64* @__hike_region_begin_count_stat
  %ac = load i64, i64* @__hike_region_active_stat
  %ac1 = add i64 %ac, 1
  store i64 %ac1, i64* @__hike_region_active_stat
  %r = call i8* @malloc(i64 24)
  %buf = call i8* @malloc(i64 65536)
  %rp = bitcast i8* %r to %struct.__hike_region*
  %p0 = getelementptr %struct.__hike_region, %struct.__hike_region* %rp, i32 0, i32 0
  store i8* %buf, i8** %p0
  %p1 = getelementptr %struct.__hike_region, %struct.__hike_region* %rp, i32 0, i32 1
  store i64 0, i64* %p1
  %p2 = getelementptr %struct.__hike_region, %struct.__hike_region* %rp, i32 0, i32 2
  store i64 65536, i64* %p2
  ret i8* %r
}
define internal i8* @__hike_region_alloc(i8* %r, i64 %n) {
entry:
  %rp = bitcast i8* %r to %struct.__hike_region*
  %p1 = getelementptr %struct.__hike_region, %struct.__hike_region* %rp, i32 0, i32 1
  %old = load i64, i64* %p1
  %aligned0 = add i64 %old, 7
  %aligned = and i64 %aligned0, -8
  %next = add i64 %aligned, %n
  %p2 = getelementptr %struct.__hike_region, %struct.__hike_region* %rp, i32 0, i32 2
  %cap = load i64, i64* %p2
  %ok = icmp ule i64 %next, %cap
  br i1 %ok, label %in, label %fallback
in:
  %p0 = getelementptr %struct.__hike_region, %struct.__hike_region* %rp, i32 0, i32 0
  %buf = load i8*, i8** %p0
  %ret = getelementptr i8, i8* %buf, i64 %aligned
  store i64 %next, i64* %p1
  %ab = load i64, i64* @__hike_region_allocated_bytes_stat
  %ab1 = add i64 %ab, %n
  store i64 %ab1, i64* @__hike_region_allocated_bytes_stat
  ret i8* %ret
fallback:
  %heap = call i8* @malloc(i64 %n)
  ret i8* %heap
}
define internal void @__hike_region_end(i8* %r) {
entry:
  %rp = bitcast i8* %r to %struct.__hike_region*
  %p0 = getelementptr %struct.__hike_region, %struct.__hike_region* %rp, i32 0, i32 0
  %buf = load i8*, i8** %p0
  %usedp = getelementptr %struct.__hike_region, %struct.__hike_region* %rp, i32 0, i32 1
  %used = load i64, i64* %usedp
  %rel = load i64, i64* @__hike_region_released_bytes_stat
  %rel1 = add i64 %rel, %used
  store i64 %rel1, i64* @__hike_region_released_bytes_stat
  %ec = load i64, i64* @__hike_region_end_count_stat
  %ec1 = add i64 %ec, 1
  store i64 %ec1, i64* @__hike_region_end_count_stat
  %ac = load i64, i64* @__hike_region_active_stat
  %ac1 = sub i64 %ac, 1
  store i64 %ac1, i64* @__hike_region_active_stat
  call void @free(i8* %buf)
  call void @free(i8* %r)
  ret void
}

; Lexical area allocator. A root area owns a separate arena. Nested areas
; reserve half of the remaining parent area and restore the parent cursor on
; exit, so all nested allocations become invalid in O(1).
%struct.__hike_area = type { i8*, i64, i64, i8*, i64 }
define internal i8* @__hike_area_begin(i64 %size, i8* %parent) {
entry:
  %a = call i8* @malloc(i64 40)
  %isroot = icmp eq i8* %parent, null
  br i1 %isroot, label %root, label %nested
root:
  %default = icmp eq i64 %size, 0
  %cap = select i1 %default, i64 16384, i64 %size
  %buf = call i8* @malloc(i64 %cap)
  %ap = bitcast i8* %a to %struct.__hike_area*
  %p0 = getelementptr %struct.__hike_area, %struct.__hike_area* %ap, i32 0, i32 0
  store i8* %buf, i8** %p0
  %p1 = getelementptr %struct.__hike_area, %struct.__hike_area* %ap, i32 0, i32 1
  store i64 0, i64* %p1
  %p2 = getelementptr %struct.__hike_area, %struct.__hike_area* %ap, i32 0, i32 2
  store i64 %cap, i64* %p2
  %p3 = getelementptr %struct.__hike_area, %struct.__hike_area* %ap, i32 0, i32 3
  store i8* null, i8** %p3
  %p4 = getelementptr %struct.__hike_area, %struct.__hike_area* %ap, i32 0, i32 4
  store i64 0, i64* %p4
  ret i8* %a
nested:
  %pp = bitcast i8* %parent to %struct.__hike_area*
  %usedp = getelementptr %struct.__hike_area, %struct.__hike_area* %pp, i32 0, i32 1
  %start = load i64, i64* %usedp
  %capp = getelementptr %struct.__hike_area, %struct.__hike_area* %pp, i32 0, i32 2
  %pcap = load i64, i64* %capp
  %remaining = sub i64 %pcap, %start
  %half = udiv i64 %remaining, 2
  %next = add i64 %start, %half
  store i64 %next, i64* %usedp
  %bufp = getelementptr %struct.__hike_area, %struct.__hike_area* %pp, i32 0, i32 0
  %base = load i8*, i8** %bufp
  %bufn = getelementptr i8, i8* %base, i64 %start
  %apn = bitcast i8* %a to %struct.__hike_area*
  %n0 = getelementptr %struct.__hike_area, %struct.__hike_area* %apn, i32 0, i32 0
  store i8* %bufn, i8** %n0
  %n1 = getelementptr %struct.__hike_area, %struct.__hike_area* %apn, i32 0, i32 1
  store i64 0, i64* %n1
  %n2 = getelementptr %struct.__hike_area, %struct.__hike_area* %apn, i32 0, i32 2
  store i64 %half, i64* %n2
  %n3 = getelementptr %struct.__hike_area, %struct.__hike_area* %apn, i32 0, i32 3
  store i8* %parent, i8** %n3
  %n4 = getelementptr %struct.__hike_area, %struct.__hike_area* %apn, i32 0, i32 4
  store i64 %start, i64* %n4
  ret i8* %a
}
define internal i8* @__hike_area_alloc(i8* %r, i64 %n) {
entry:
  %rp = bitcast i8* %r to %struct.__hike_area*
  %p1 = getelementptr %struct.__hike_area, %struct.__hike_area* %rp, i32 0, i32 1
  %old = load i64, i64* %p1
  %aligned0 = add i64 %old, 7
  %aligned = and i64 %aligned0, -8
  %next = add i64 %aligned, %n
  %p2 = getelementptr %struct.__hike_area, %struct.__hike_area* %rp, i32 0, i32 2
  %cap = load i64, i64* %p2
  %ok = icmp ule i64 %next, %cap
  br i1 %ok, label %in, label %fallback
in:
  %p0 = getelementptr %struct.__hike_area, %struct.__hike_area* %rp, i32 0, i32 0
  %buf = load i8*, i8** %p0
  %ret = getelementptr i8, i8* %buf, i64 %aligned
  store i64 %next, i64* %p1
  ret i8* %ret
fallback:
  %heap = call i8* @malloc(i64 %n)
  ret i8* %heap
}
define internal void @__hike_area_end(i8* %r) {
entry:
  %rp = bitcast i8* %r to %struct.__hike_area*
  %p3 = getelementptr %struct.__hike_area, %struct.__hike_area* %rp, i32 0, i32 3
  %parent = load i8*, i8** %p3
  %nested = icmp ne i8* %parent, null
  br i1 %nested, label %restore, label %root
restore:
  %pp = bitcast i8* %parent to %struct.__hike_area*
  %usedp = getelementptr %struct.__hike_area, %struct.__hike_area* %pp, i32 0, i32 1
  %p4 = getelementptr %struct.__hike_area, %struct.__hike_area* %rp, i32 0, i32 4
  %start = load i64, i64* %p4
  store i64 %start, i64* %usedp
  call void @free(i8* %r)
  ret void
root:
  %p0 = getelementptr %struct.__hike_area, %struct.__hike_area* %rp, i32 0, i32 0
  %buf = load i8*, i8** %p0
  call void @free(i8* %buf)
  call void @free(i8* %r)
  ret void
}

; ------------------------------------------------------------------------------
; Pure Memory & String Builtin Implementations (64-bit Native, Libc-Free)
; ------------------------------------------------------------------------------

; メモリブロックの複製 (64-bit)
define internal i8* @memcpy(i8* %dst, i8* %src, i64 %n) #0 {
entry:
  %cmp = icmp eq i64 %n, 0
  br i1 %cmp, label %exit, label %loop.body
loop.body:
  %i = phi i64 [ 0, %entry ], [ %i.next, %loop.body ]
  %p_src = getelementptr inbounds i8, i8* %src, i64 %i
  %val = load i8, i8* %p_src, align 1
  %p_dst = getelementptr inbounds i8, i8* %dst, i64 %i
  store i8 %val, i8* %p_dst, align 1
  %i.next = add i64 %i, 1
  %cont = icmp ult i64 %i.next, %n
  br i1 %cont, label %loop.body, label %exit
exit:
  ret i8* %dst
}

; メモリブロックの比較 (64-bit)
define internal i32 @memcmp(i8* %s1, i8* %s2, i64 %n) #0 {
entry:
  %cmp = icmp eq i64 %n, 0
  br i1 %cmp, label %ret_zero, label %loop.body
loop.body:
  %i = phi i64 [ 0, %entry ], [ %i.next, %loop.inc ]
  %p1 = getelementptr inbounds i8, i8* %s1, i64 %i
  %b1 = load i8, i8* %p1, align 1
  %p2 = getelementptr inbounds i8, i8* %s2, i64 %i
  %b2 = load i8, i8* %p2, align 1
  %diff = icmp ne i8 %b1, %b2
  br i1 %diff, label %calc_diff, label %loop.inc
loop.inc:
  %i.next = add i64 %i, 1
  %cont = icmp ult i64 %i.next, %n
  br i1 %cont, label %loop.body, label %ret_zero
calc_diff:
  %u1 = zext i8 %b1 to i32
  %u2 = zext i8 %b2 to i32
  %res = sub i32 %u1, %u2
  ret i32 %res
ret_zero:
  ret i32 0
}

; 文字列長の算出 (64-bit)
define internal i64 @strlen(i8* %s) #0 {
entry:
  %is_null = icmp eq i8* %s, null
  br i1 %is_null, label %ret_zero, label %loop.body
loop.body:
  %len = phi i64 [ 0, %entry ], [ %len.next, %loop.body ]
  %p = getelementptr inbounds i8, i8* %s, i64 %len
  %c = load i8, i8* %p, align 1
  %is_end = icmp eq i8 %c, 0
  %len.next = add i64 %len, 1
  br i1 %is_end, label %ret_len, label %loop.body
ret_len:
  ret i64 %len
ret_zero:
  ret i64 0
}

; 文字列の辞書順比較 (64-bit)
define internal i32 @strcmp(i8* %s1, i8* %s2) #0 {
entry:
  %eq_ptr = icmp eq i8* %s1, %s2
  br i1 %eq_ptr, label %ret_zero, label %check_null
check_null:
  %n1 = icmp eq i8* %s1, null
  %n2 = icmp eq i8* %s2, null
  %either_null = or i1 %n1, %n2
  br i1 %either_null, label %s1_is_null, label %check_s2
s1_is_null:
  br i1 %n2, label %ret_zero, label %ret_neg
check_s2:
  br i1 %n2, label %ret_pos, label %loop.body
ret_neg:
  ret i32 -1
ret_pos:
  ret i32 1
ret_zero:
  ret i32 0
loop.body:
  %idx = phi i64 [ 0, %check_s2 ], [ %idx.next, %loop.inc ]
  %p1 = getelementptr inbounds i8, i8* %s1, i64 %idx
  %c1 = load i8, i8* %p1, align 1
  %p2 = getelementptr inbounds i8, i8* %s2, i64 %idx
  %c2 = load i8, i8* %p2, align 1
  %diff = icmp ne i8 %c1, %c2
  br i1 %diff, label %calc_diff, label %check_end
check_end:
  %is_end = icmp eq i8 %c1, 0
  br i1 %is_end, label %ret_zero, label %loop.inc
loop.inc:
  %idx.next = add i64 %idx, 1
  br label %loop.body
calc_diff:
  %u1 = zext i8 %c1 to i32
  %u2 = zext i8 %c2 to i32
  %res = sub i32 %u1, %u2
  ret i32 %res
}

; ------------------------------------------------------------------------------
; OS Native Threading & Synchronization (Kernel32 / Libc-Free)
; ------------------------------------------------------------------------------
; ------------------------------------------------------------------------------
; Memory Management Types
; ------------------------------------------------------------------------------
%struct.Arena = type { i8*, i64, i64 }
%struct.Allocator = type { i8*, i8* }

; ------------------------------------------------------------------------------
; Standard OS Native Sleep & Time Binding (std/time)
; ------------------------------------------------------------------------------

define internal void @c_os_sleep_ms(i32 %ms) {
entry:
  call void @hike_sleep_ms(i32 %ms)
  ret void
}

define internal void @os_sleep_ms(i32 %ms) {
entry:
  call void @hike_sleep_ms(i32 %ms)
  ret void
}

define internal i64 @c_os_now_ns() {
entry:
  %ms = call i64 @hike_now_ns()
  %ns = mul i64 %ms, 1
  ret i64 %ns
}

define internal i64 @os_now_ns() {
entry:
  %ms = call i64 @hike_now_ns()
  %ns = mul i64 %ms, 1
  ret i64 %ns
}

; ------------------------------------------------------------------------------
; Async Thread Pool & Task Runtime
; ------------------------------------------------------------------------------

; %struct.__hike_task = { fn_thunk, env_ptr, ret_buf, completed, event_handle }
%struct.__hike_task = type { void (i8*, i8*)*, i8*, i8*, i32, i8* }

; スレッドプールワーカースレッドのエントリルーチン
define internal i32 @__hike_task_worker_thunk(i8* %param) {
entry:
  %task = bitcast i8* %param to %struct.__hike_task*
  %p_fn = getelementptr inbounds %struct.__hike_task, %struct.__hike_task* %task, i32 0, i32 0
  %fn = load void (i8*, i8*)*, void (i8*, i8*)** %p_fn
  %p_env = getelementptr inbounds %struct.__hike_task, %struct.__hike_task* %task, i32 0, i32 1
  %env = load i8*, i8** %p_env
  %p_buf = getelementptr inbounds %struct.__hike_task, %struct.__hike_task* %task, i32 0, i32 2
  %buf = load i8*, i8** %p_buf

  ; タスク本体（サンク）の実行
  call void %fn(i8* %env, i8* %buf)

  ; 完了状態へ遷移
  %p_done = getelementptr inbounds %struct.__hike_task, %struct.__hike_task* %task, i32 0, i32 3
  store i32 1, i32* %p_done

  ; 待機側スレッドへの起床シグナル発火
  %p_ev = getelementptr inbounds %struct.__hike_task, %struct.__hike_task* %task, i32 0, i32 4
  %ev = load i8*, i8** %p_ev
  %ev_null = icmp eq i8* %ev, null
  br i1 %ev_null, label %exit, label %signal_ev
signal_ev:
  call i32 @hike_event_signal(i8* %ev)
  br label %exit
exit:
  ret i32 0
}

; スレッドプールへの非同期タスク投入
define internal %struct.__hike_task* @__hike_async(i8* %fn_ptr, i8* %env_ptr, i64 %ret_size) {
entry:
  %raw_task = call i8* @malloc(i64 40)
  %task = bitcast i8* %raw_task to %struct.__hike_task*

  ; 関数ポインタ・環境ポインタの設定
  %fn_thunk = bitcast i8* %fn_ptr to void (i8*, i8*)*
  %p_fn = getelementptr inbounds %struct.__hike_task, %struct.__hike_task* %task, i32 0, i32 0
  store void (i8*, i8*)* %fn_thunk, void (i8*, i8*)** %p_fn

  %p_env = getelementptr inbounds %struct.__hike_task, %struct.__hike_task* %task, i32 0, i32 1
  store i8* %env_ptr, i8** %p_env

  ; 戻り値格納バッファの確保
  %need_buf = icmp sgt i64 %ret_size, 0
  br i1 %need_buf, label %alloc_buf, label %no_buf
alloc_buf:
  %buf = call i8* @malloc(i64 %ret_size)
  br label %set_buf
no_buf:
  br label %set_buf
set_buf:
  %buf_val = phi i8* [ %buf, %alloc_buf ], [ null, %no_buf ]
  %p_buf = getelementptr inbounds %struct.__hike_task, %struct.__hike_task* %task, i32 0, i32 2
  store i8* %buf_val, i8** %p_buf

  ; 完了フラグ初期化 (0: 実行中)
  %p_done = getelementptr inbounds %struct.__hike_task, %struct.__hike_task* %task, i32 0, i32 3
  store i32 0, i32* %p_done

  ; 同期イベントの生成 (自動リセット)
  %ev = call i8* @hike_event_create()
  %p_ev = getelementptr inbounds %struct.__hike_task, %struct.__hike_task* %task, i32 0, i32 4
  store i8* %ev, i8** %p_ev

  ; OS スレッドプールへ投入 (WT_EXECUTEDEFAULT = 0)
  call i32 @hike_thread_spawn(i32 (i8*)* @__hike_task_worker_thunk, i8* %raw_task)

  ret %struct.__hike_task* %task
}

; タスクの同期待ち (<- 演算子の実体)
define internal i8* @__hike_task_wait(%struct.__hike_task* %task) {
entry:
  %task_null = icmp eq %struct.__hike_task* %task, null
  br i1 %task_null, label %ret_null, label %check_done
ret_null:
  ret i8* null
check_done:
  %p_done = getelementptr inbounds %struct.__hike_task, %struct.__hike_task* %task, i32 0, i32 3
  %done = load i32, i32* %p_done
  %is_done = icmp ne i32 %done, 0
  br i1 %is_done, label %get_res, label %wait_ev
wait_ev:
  %p_ev = getelementptr inbounds %struct.__hike_task, %struct.__hike_task* %task, i32 0, i32 4
  %ev = load i8*, i8** %p_ev
  %has_ev = icmp ne i8* %ev, null
  br i1 %has_ev, label %do_wait, label %poll_loop
do_wait:
  ; INFINITE = 0xFFFFFFFF (-1)
  call i32 @hike_event_wait(i8* %ev, i32 -1)
  call i32 @hike_event_destroy(i8* %ev)
  store i8* null, i8** %p_ev
  br label %get_res
poll_loop:
  call void @hike_sleep_ms(i32 1)
  %done_poll = load i32, i32* %p_done
  %is_done_poll = icmp ne i32 %done_poll, 0
  br i1 %is_done_poll, label %get_res, label %poll_loop
get_res:
  %p_buf = getelementptr inbounds %struct.__hike_task, %struct.__hike_task* %task, i32 0, i32 2
  %buf = load i8*, i8** %p_buf
  ret i8* %buf
}

; ------------------------------------------------------------------------------
; Channel & Concurrency Queue Runtime
; ------------------------------------------------------------------------------

; %struct.__hike_chan = { elem_size, cap, count, head, tail, buf, lock, closed, ev_recv, ev_send }
%struct.__hike_chan = type { i64, i64, i64, i64, i64, i8*, i32, i32, i8*, i8* }

; チャネル内部スピンロックの獲得 (Yield 付き)
define internal void @__hike_chan_lock(i32* %lock) {
entry:
  br label %spin
spin:
  %prev = atomicrmw xchg i32* %lock, i32 1 seq_cst
  %is_free = icmp eq i32 %prev, 0
  br i1 %is_free, label %acquired, label %wait
wait:
  call void @hike_sleep_ms(i32 0)
  br label %spin
acquired:
  ret void
}

; チャネル内部スピンロックの解放
define internal void @__hike_chan_unlock(i32* %lock) {
entry:
  store atomic i32 0, i32* %lock seq_cst, align 4
  ret void
}

; チャネルの新規生成 (make(chan T, cap))
define internal i8* @__hike_chan_make(i64 %elem_size, i64 %cap) {
entry:
  %cap_le_0 = icmp sle i64 %cap, 0
  %real_cap = select i1 %cap_le_0, i64 1, i64 %cap

  %raw = call i8* @malloc(i64 72)
  %ch = bitcast i8* %raw to %struct.__hike_chan*

  %buf_bytes = mul i64 %real_cap, %elem_size
  %buf = call i8* @malloc(i64 %buf_bytes)

  %p_es = getelementptr inbounds %struct.__hike_chan, %struct.__hike_chan* %ch, i32 0, i32 0
  store i64 %elem_size, i64* %p_es
  %p_cap = getelementptr inbounds %struct.__hike_chan, %struct.__hike_chan* %ch, i32 0, i32 1
  store i64 %real_cap, i64* %p_cap
  %p_cnt = getelementptr inbounds %struct.__hike_chan, %struct.__hike_chan* %ch, i32 0, i32 2
  store i64 0, i64* %p_cnt
  %p_hd = getelementptr inbounds %struct.__hike_chan, %struct.__hike_chan* %ch, i32 0, i32 3
  store i64 0, i64* %p_hd
  %p_tl = getelementptr inbounds %struct.__hike_chan, %struct.__hike_chan* %ch, i32 0, i32 4
  store i64 0, i64* %p_tl
  %p_buf = getelementptr inbounds %struct.__hike_chan, %struct.__hike_chan* %ch, i32 0, i32 5
  store i8* %buf, i8** %p_buf
  %p_lock = getelementptr inbounds %struct.__hike_chan, %struct.__hike_chan* %ch, i32 0, i32 6
  store i32 0, i32* %p_lock
  %p_cls = getelementptr inbounds %struct.__hike_chan, %struct.__hike_chan* %ch, i32 0, i32 7
  store i32 0, i32* %p_cls

  ; 自動リセットイベントの生成 (受信側・送信側)
  %ev_recv = call i8* @hike_event_create()
  %p_ev_r = getelementptr inbounds %struct.__hike_chan, %struct.__hike_chan* %ch, i32 0, i32 8
  store i8* %ev_recv, i8** %p_ev_r

  %ev_send = call i8* @hike_event_create()
  %p_ev_s = getelementptr inbounds %struct.__hike_chan, %struct.__hike_chan* %ch, i32 0, i32 9
  store i8* %ev_send, i8** %p_ev_s

  ret i8* %raw
}

; チャネルへの値送信 (ch <- val)
define internal void @__hike_chan_send(i8* %ch_raw, i8* %val_ptr) {
entry:
  %ch = bitcast i8* %ch_raw to %struct.__hike_chan*
  %p_lock = getelementptr inbounds %struct.__hike_chan, %struct.__hike_chan* %ch, i32 0, i32 6
  %p_cnt = getelementptr inbounds %struct.__hike_chan, %struct.__hike_chan* %ch, i32 0, i32 2
  %p_cap = getelementptr inbounds %struct.__hike_chan, %struct.__hike_chan* %ch, i32 0, i32 1
  %p_tl = getelementptr inbounds %struct.__hike_chan, %struct.__hike_chan* %ch, i32 0, i32 4
  %p_es = getelementptr inbounds %struct.__hike_chan, %struct.__hike_chan* %ch, i32 0, i32 0
  %p_buf = getelementptr inbounds %struct.__hike_chan, %struct.__hike_chan* %ch, i32 0, i32 5
  %p_cls = getelementptr inbounds %struct.__hike_chan, %struct.__hike_chan* %ch, i32 0, i32 7
  %p_ev_r = getelementptr inbounds %struct.__hike_chan, %struct.__hike_chan* %ch, i32 0, i32 8
  %p_ev_s = getelementptr inbounds %struct.__hike_chan, %struct.__hike_chan* %ch, i32 0, i32 9
  br label %try_send

try_send:
  call void @__hike_chan_lock(i32* %p_lock)
  ; クローズ済みチャネルへの送信チェック (デッドロック抑止)
  %cls = load i32, i32* %p_cls
  %is_closed = icmp ne i32 %cls, 0
  br i1 %is_closed, label %on_closed_send, label %check_room

on_closed_send:
  call void @__hike_chan_unlock(i32* %p_lock)
  ret void

check_room:
  %cnt = load i64, i64* %p_cnt
  %cap = load i64, i64* %p_cap
  %has_room = icmp slt i64 %cnt, %cap
  br i1 %has_room, label %do_send, label %full

do_send:
  %tl = load i64, i64* %p_tl
  %es = load i64, i64* %p_es
  %buf = load i8*, i8** %p_buf
  %offset = mul i64 %tl, %es
  %dst = getelementptr inbounds i8, i8* %buf, i64 %offset
  call i8* @memcpy(i8* %dst, i8* %val_ptr, i64 %es)

  %next_tl_raw = add i64 %tl, 1
  %next_tl = urem i64 %next_tl_raw, %cap
  store i64 %next_tl, i64* %p_tl

  %next_cnt = add i64 %cnt, 1
  store i64 %next_cnt, i64* %p_cnt

  ; 受信待ちスレッドを起床
  %ev_r = load i8*, i8** %p_ev_r
  call i32 @hike_event_signal(i8* %ev_r)

  call void @__hike_chan_unlock(i32* %p_lock)
  ret void

full:
  call void @__hike_chan_unlock(i32* %p_lock)
  %ev_s = load i8*, i8** %p_ev_s
  call i32 @hike_event_wait(i8* %ev_s, i32 10)
  br label %try_send
}

; チャネルからの値受信 (<-ch)
define internal void @__hike_chan_recv(i8* %ch_raw, i8* %val_ptr) {
entry:
  %ch = bitcast i8* %ch_raw to %struct.__hike_chan*
  %p_lock = getelementptr inbounds %struct.__hike_chan, %struct.__hike_chan* %ch, i32 0, i32 6
  %p_cnt = getelementptr inbounds %struct.__hike_chan, %struct.__hike_chan* %ch, i32 0, i32 2
  %p_cap = getelementptr inbounds %struct.__hike_chan, %struct.__hike_chan* %ch, i32 0, i32 1
  %p_hd = getelementptr inbounds %struct.__hike_chan, %struct.__hike_chan* %ch, i32 0, i32 3
  %p_es = getelementptr inbounds %struct.__hike_chan, %struct.__hike_chan* %ch, i32 0, i32 0
  %p_buf = getelementptr inbounds %struct.__hike_chan, %struct.__hike_chan* %ch, i32 0, i32 5
  %p_cls = getelementptr inbounds %struct.__hike_chan, %struct.__hike_chan* %ch, i32 0, i32 7
  %p_ev_r = getelementptr inbounds %struct.__hike_chan, %struct.__hike_chan* %ch, i32 0, i32 8
  %p_ev_s = getelementptr inbounds %struct.__hike_chan, %struct.__hike_chan* %ch, i32 0, i32 9
  br label %try_recv

try_recv:
  call void @__hike_chan_lock(i32* %p_lock)
  %cnt = load i64, i64* %p_cnt
  %has_data = icmp sgt i64 %cnt, 0
  br i1 %has_data, label %do_recv, label %empty

do_recv:
  %hd = load i64, i64* %p_hd
  %cap = load i64, i64* %p_cap
  %es = load i64, i64* %p_es
  %buf = load i8*, i8** %p_buf
  %offset = mul i64 %hd, %es
  %src = getelementptr inbounds i8, i8* %buf, i64 %offset
  call i8* @memcpy(i8* %val_ptr, i8* %src, i64 %es)

  %next_hd_raw = add i64 %hd, 1
  %next_hd = urem i64 %next_hd_raw, %cap
  store i64 %next_hd, i64* %p_hd

  %next_cnt = sub i64 %cnt, 1
  store i64 %next_cnt, i64* %p_cnt

  ; 送信待ちスレッドを起床
  %ev_s = load i8*, i8** %p_ev_s
  call i32 @hike_event_signal(i8* %ev_s)

  call void @__hike_chan_unlock(i32* %p_lock)
  ret void

empty:
  %cls = load i32, i32* %p_cls
  %is_closed = icmp ne i32 %cls, 0
  br i1 %is_closed, label %on_closed, label %wait_data

on_closed:
  ; クローズ済みで空の場合はゼロ値（null / 0）を書き込んで即座に復帰
  %es_c = load i64, i64* %p_es
  br label %zero_loop.cond

zero_loop.cond:
  %zi = phi i64 [ 0, %on_closed ], [ %zi.next, %zero_loop.body ]
  %z_cmp = icmp slt i64 %zi, %es_c
  br i1 %z_cmp, label %zero_loop.body, label %zero_loop.end

zero_loop.body:
  %z_ptr = getelementptr inbounds i8, i8* %val_ptr, i64 %zi
  store i8 0, i8* %z_ptr
  %zi.next = add i64 %zi, 1
  br label %zero_loop.cond

zero_loop.end:
  call void @__hike_chan_unlock(i32* %p_lock)
  ret void

wait_data:
  call void @__hike_chan_unlock(i32* %p_lock)
  ; 空の間は OS イベントでスリープ待機 (CPU 使用率 0%)
  %ev_r = load i8*, i8** %p_ev_r
  call i32 @hike_event_wait(i8* %ev_r, i32 10)
  br label %try_recv
}

; チャネルのクローズ (close(ch))
define internal void @__hike_chan_close(i8* %ch_raw) {
entry:
  %ch = bitcast i8* %ch_raw to %struct.__hike_chan*
  %p_lock = getelementptr inbounds %struct.__hike_chan, %struct.__hike_chan* %ch, i32 0, i32 6
  %p_cls = getelementptr inbounds %struct.__hike_chan, %struct.__hike_chan* %ch, i32 0, i32 7
  %p_ev_r = getelementptr inbounds %struct.__hike_chan, %struct.__hike_chan* %ch, i32 0, i32 8
  %p_ev_s = getelementptr inbounds %struct.__hike_chan, %struct.__hike_chan* %ch, i32 0, i32 9

  call void @__hike_chan_lock(i32* %p_lock)
  store i32 1, i32* %p_cls

  ; 待機中の全スレッドを起床させて終了状態を検知させる
  %ev_r = load i8*, i8** %p_ev_r
  call i32 @hike_event_signal(i8* %ev_r)

  %ev_s = load i8*, i8** %p_ev_s
  call i32 @hike_event_signal(i8* %ev_s)

  call void @__hike_chan_unlock(i32* %p_lock)
  ret void
}

; ------------------------------------------------------------------------------
; String Runtime Functions (64-bit)
; ------------------------------------------------------------------------------

; Reference-count operations receive the payload pointer. The allocation
; header is stored immediately before it: capacity at -8 and refcount at -4.
define internal void @__hike_string_retain(i8* %data, i32 %offset) #0 {
entry:
  %literal = icmp slt i32 %offset, 0
  br i1 %literal, label %done, label %load
load:
  %raw = getelementptr inbounds i8, i8* %data, i64 -8
  %ref = getelementptr inbounds i8, i8* %raw, i64 4
  %ref32 = bitcast i8* %ref to i32*
  %old = load i32, i32* %ref32
  %immortal = icmp eq i32 %old, -2147483648
  br i1 %immortal, label %done, label %increment
increment:
  %next = add i32 %old, 1
  store i32 %next, i32* %ref32
  br label %done
done:
  ret void
}

define internal void @__hike_string_release(i8* %data, i32 %offset) #0 {
entry:
  %is_null = icmp eq i8* %data, null
  %literal = icmp slt i32 %offset, 0
  %skip = or i1 %is_null, %literal
  br i1 %skip, label %done, label %decrement
decrement:
  %raw = getelementptr inbounds i8, i8* %data, i64 -8
  %ref = getelementptr inbounds i8, i8* %raw, i64 4
  %ref32 = bitcast i8* %ref to i32*
  %old = load i32, i32* %ref32
  %immortal = icmp eq i32 %old, -2147483648
  br i1 %immortal, label %done, label %decrement_count
decrement_count:
  %next = sub i32 %old, 1
  store i32 %next, i32* %ref32
  %last = icmp eq i32 %next, 0
  br i1 %last, label %free_buffer, label %done
free_buffer:
  call void @free(i8* %raw)
  br label %done
done:
  ret void
}

; Return a writable string view.  A uniquely owned heap buffer is reused;
; shared or static storage is copied and the old reference is released.
define internal { i8*, i32, i32 } @__hike_string_writable(i8* %base, i32 %offset, i32 %len) #0 {
entry:
  %literal = icmp slt i32 %offset, 0
  br i1 %literal, label %copy_literal, label %load_header
load_header:
  %raw = getelementptr inbounds i8, i8* %base, i64 -8
  %ref = getelementptr inbounds i8, i8* %raw, i64 4
  %ref32 = bitcast i8* %ref to i32*
  %count = load i32, i32* %ref32
  %unique = icmp eq i32 %count, 1
  br i1 %unique, label %reuse, label %copy
copy_literal:
  %literal_size64 = zext i32 %len to i64
  %literal_alloc_size = add i64 %literal_size64, 9
  %literal_raw = call i8* @malloc(i64 %literal_alloc_size)
  %literal_cap_ptr = bitcast i8* %literal_raw to i32*
  store i32 %len, i32* %literal_cap_ptr
  %literal_ref = getelementptr inbounds i8, i8* %literal_raw, i64 4
  %literal_ref32 = bitcast i8* %literal_ref to i32*
  store i32 1, i32* %literal_ref32
  %literal_data = getelementptr inbounds i8, i8* %literal_raw, i64 8
  call i8* @memcpy(i8* %literal_data, i8* %base, i64 %literal_size64)
  %literal_nul = getelementptr inbounds i8, i8* %literal_data, i64 %literal_size64
  store i8 0, i8* %literal_nul
  %literal_copy0 = insertvalue { i8*, i32, i32 } undef, i8* %literal_data, 0
  %literal_copy1 = insertvalue { i8*, i32, i32 } %literal_copy0, i32 0, 1
  %literal_copy2 = insertvalue { i8*, i32, i32 } %literal_copy1, i32 %len, 2
  ret { i8*, i32, i32 } %literal_copy2
reuse:
  %reuse0 = insertvalue { i8*, i32, i32 } undef, i8* %base, 0
  %reuse1 = insertvalue { i8*, i32, i32 } %reuse0, i32 %offset, 1
  %reuse2 = insertvalue { i8*, i32, i32 } %reuse1, i32 %len, 2
  ret { i8*, i32, i32 } %reuse2
copy:
  %size64 = zext i32 %len to i64
  %alloc_size = add i64 %size64, 9
  %new_raw = call i8* @malloc(i64 %alloc_size)
  %cap_ptr = bitcast i8* %new_raw to i32*
  store i32 %len, i32* %cap_ptr
  %new_ref = getelementptr inbounds i8, i8* %new_raw, i64 4
  %new_ref32 = bitcast i8* %new_ref to i32*
  store i32 1, i32* %new_ref32
  %new_data = getelementptr inbounds i8, i8* %new_raw, i64 8
  %offset64 = zext i32 %offset to i64
  %src = getelementptr inbounds i8, i8* %base, i64 %offset64
  call i8* @memcpy(i8* %new_data, i8* %src, i64 %size64)
  %nul = getelementptr inbounds i8, i8* %new_data, i64 %size64
  store i8 0, i8* %nul
  %immortal = icmp eq i32 %count, -2147483648
  br i1 %immortal, label %return_copy, label %decrement_old
decrement_old:
  %old_next = sub i32 %count, 1
  %old_last = icmp eq i32 %old_next, 0
  store i32 %old_next, i32* %ref32
  br i1 %old_last, label %free_old, label %return_copy
free_old:
  call void @free(i8* %raw)
  br label %return_copy
return_copy:
  %copy0 = insertvalue { i8*, i32, i32 } undef, i8* %new_data, 0
  %copy1 = insertvalue { i8*, i32, i32 } %copy0, i32 0, 1
  %copy2 = insertvalue { i8*, i32, i32 } %copy1, i32 %len, 2
  ret { i8*, i32, i32 } %copy2
}

; Append to a string variable. Unique buffers reserve 256 bytes on the first
; append and are reused while the accumulated string fits in that capacity.
; The bootstrap compiler only requires the runtime entry point for sort.Strings
; to be linkable. The Hike stdlib currently provides ordering at the source
; level, so keep this ABI-compatible fallback as a no-op until native sorting
; is lowered directly.
define internal void @__hike_sort_strings({ i8*, i64, i64 } %items) #0 {
entry:
  ret void
}

define internal i8* @__hike_string_append(i8* %base, i32 %offset, i32 %len, i8* %b, i32 %blen) #0 {
entry:
  %total = add i32 %len, %blen
  %len64 = zext i32 %len to i64
  %blen64 = zext i32 %blen to i64
  %literal = icmp slt i32 %offset, 0
  br i1 %literal, label %copy_literal, label %load_header
load_header:
  %raw = getelementptr inbounds i8, i8* %base, i64 -8
  %cap_ptr = bitcast i8* %raw to i32*
  %cap = load i32, i32* %cap_ptr
  %ref = getelementptr inbounds i8, i8* %raw, i64 4
  %ref32 = bitcast i8* %ref to i32*
  %count = load i32, i32* %ref32
  %available = sub i32 %cap, %offset
  %fits = icmp uge i32 %available, %total
  %unique = icmp eq i32 %count, 1
  %reuse_ok = and i1 %unique, %fits
  br i1 %reuse_ok, label %reuse, label %copy
copy_literal:
  %literal_new_data = call i8* @hike_strcat_len(i8* %base, i64 %len64, i8* %b, i64 %blen64)
  ret i8* %literal_new_data
reuse:
  %dst = getelementptr inbounds i8, i8* %base, i32 %offset
  %dst_b = getelementptr inbounds i8, i8* %dst, i32 %len
  call i8* @memcpy(i8* %dst_b, i8* %b, i64 %blen64)
  %nul = getelementptr inbounds i8, i8* %dst, i32 %total
  store i8 0, i8* %nul
  ret i8* %dst
copy:
  %src = getelementptr inbounds i8, i8* %base, i32 %offset
  %new_data = call i8* @hike_strcat_len(i8* %src, i64 %len64, i8* %b, i64 %blen64)
  ; ownership: string_release var=base target=%base at runtime_common.ll:992:3
  call void @__hike_string_release(i8* %base, i32 %offset)
  ret i8* %new_data
}

; 文字列等価比較 (hike_streq: a == b) (64-bit)
define internal i1 @hike_streq(i8* %a, i8* %b) #0 {
entry:
  %eq_ptr = icmp eq i8* %a, %b
  br i1 %eq_ptr, label %ret_true, label %check_null
check_null:
  %a_null = icmp eq i8* %a, null
  %b_null = icmp eq i8* %b, null
  %either_null = or i1 %a_null, %b_null
  br i1 %either_null, label %ret_false, label %do_strcmp
do_strcmp:
  %res = call i32 @strcmp(i8* %a, i8* %b)
  %is_zero = icmp eq i32 %res, 0
  ret i1 %is_zero
ret_true:
  ret i1 true
ret_false:
  ret i1 false
}

; Length-aware string equality for fat-string views (not NUL-terminated).
define internal i1 @hike_streq_len(i8* %a, i64 %alen, i8* %b, i64 %blen) #0 {
entry:
  %same_len = icmp eq i64 %alen, %blen
  br i1 %same_len, label %compare, label %false
compare:
  %res = call i32 @memcmp(i8* %a, i8* %b, i64 %alen)
  %equal = icmp eq i32 %res, 0
  ret i1 %equal
false:
  ret i1 false
}

define internal i32 @hike_strcmp_len(i8* %a, i64 %alen, i8* %b, i64 %blen) #0 {
entry:
  %shorter = icmp ult i64 %alen, %blen
  %n = select i1 %shorter, i64 %alen, i64 %blen
  %res = call i32 @memcmp(i8* %a, i8* %b, i64 %n)
  %different = icmp ne i32 %res, 0
  br i1 %different, label %done, label %compare_len
compare_len:
  %less = icmp ult i64 %alen, %blen
  %greater = icmp ugt i64 %alen, %blen
  br i1 %less, label %ret_less, label %check_greater
check_greater:
  br i1 %greater, label %ret_greater, label %ret_equal
ret_less:
  ret i32 -1
ret_greater:
  ret i32 1
ret_equal:
  ret i32 0
done:
  ret i32 %res
}

; Length-aware concatenation for fat-string views (not NUL-terminated).
define internal i8* @hike_strcat_len(i8* %a, i64 %alen, i8* %b, i64 %blen) #0 {
entry:
  %total_len = add i64 %alen, %blen
  %double_len = shl i64 %total_len, 1
  %overflow = icmp ult i64 %double_len, %total_len
  %grown_len = select i1 %overflow, i64 %total_len, i64 %double_len
  %large = icmp ugt i64 %total_len, 256
  %capacity = select i1 %large, i64 %grown_len, i64 256
  %alloc_size = add i64 %capacity, 9
  %raw = call i8* @malloc(i64 %alloc_size)
  %cap_ptr = bitcast i8* %raw to i32*
  %capacity32 = trunc i64 %capacity to i32
  store i32 %capacity32, i32* %cap_ptr
  %ref_ptr = getelementptr inbounds i8, i8* %raw, i64 4
  %ref_ptr32 = bitcast i8* %ref_ptr to i32*
  store i32 1, i32* %ref_ptr32
  %buf = getelementptr inbounds i8, i8* %raw, i64 8
  call i8* @memcpy(i8* %buf, i8* %a, i64 %alen)
  %dst_b = getelementptr inbounds i8, i8* %buf, i64 %alen
  call i8* @memcpy(i8* %dst_b, i8* %b, i64 %blen)
  %null_ptr = getelementptr inbounds i8, i8* %buf, i64 %total_len
  store i8 0, i8* %null_ptr
  ret i8* %buf
}

; 部分文字列の切り出し (hike_substr: s[low:high]) (64-bit)
define internal i8* @hike_substr(i8* %s, i64 %low, i64 %high) #0 {
entry:
  %s_null = icmp eq i8* %s, null
  br i1 %s_null, label %ret_null, label %check_range
check_range:
  %inv = icmp slt i64 %high, %low
  br i1 %inv, label %ret_empty, label %do_sub
ret_empty:
	%empty_raw = call i8* @malloc(i64 9)
 %empty_cap = bitcast i8* %empty_raw to i32*
 store i32 0, i32* %empty_cap
	%empty_ref = getelementptr inbounds i8, i8* %empty_raw, i64 4
 %empty_ref32 = bitcast i8* %empty_ref to i32*
 store i32 1, i32* %empty_ref32
	%empty = getelementptr inbounds i8, i8* %empty_raw, i64 8
	store i8 0, i8* %empty
	ret i8* %empty
do_sub:
  %len = sub i64 %high, %low
	%alloc_size = add i64 %len, 9
	%raw = call i8* @malloc(i64 %alloc_size)
	%cap_ptr = bitcast i8* %raw to i32*
	%capacity = trunc i64 %len to i32
	store i32 %capacity, i32* %cap_ptr
	%ref_ptr = getelementptr inbounds i8, i8* %raw, i64 4
 %ref_ptr32 = bitcast i8* %ref_ptr to i32*
 store i32 1, i32* %ref_ptr32
	%buf = getelementptr inbounds i8, i8* %raw, i64 8
  %src_ptr = getelementptr inbounds i8, i8* %s, i64 %low
  call i8* @memcpy(i8* %buf, i8* %src_ptr, i64 %len)
  %null_pos = getelementptr inbounds i8, i8* %buf, i64 %len
  store i8 0, i8* %null_pos
  ret i8* %buf
ret_null:
  ret i8* null
}

; 文字列連結 (hike_strcat: a + b) (64-bit)
define internal i8* @hike_strcat(i8* %a, i8* %b) #0 {
entry:
  %len_a = call i64 @strlen(i8* %a)
  %len_b = call i64 @strlen(i8* %b)
  %total_len = add i64 %len_a, %len_b
	%alloc_size = add i64 %total_len, 9
	%raw = call i8* @malloc(i64 %alloc_size)
	%cap_ptr = bitcast i8* %raw to i32*
	%capacity = trunc i64 %total_len to i32
	store i32 %capacity, i32* %cap_ptr
	%ref_ptr = getelementptr inbounds i8, i8* %raw, i64 4
	%ref_ptr32 = bitcast i8* %ref_ptr to i32*
  store i32 1, i32* %ref_ptr32
	%buf = getelementptr inbounds i8, i8* %raw, i64 8
  call i8* @memcpy(i8* %buf, i8* %a, i64 %len_a)
  %dst_b = getelementptr inbounds i8, i8* %buf, i64 %len_a
  call i8* @memcpy(i8* %dst_b, i8* %b, i64 %len_b)
  %null_ptr = getelementptr inbounds i8, i8* %buf, i64 %total_len
  store i8 0, i8* %null_ptr
  ret i8* %buf
}

; スライス ([]byte) から null 終端文字列 (string) への安全な複製変換 (64-bit)
define internal i8* @__hike_slice_to_str(i8* %ptr, i64 %len) #0 {
entry:
  %null_chk = icmp eq i8* %ptr, null
  br i1 %null_chk, label %ret_empty, label %alloc
ret_empty:
	%empty_raw = call i8* @malloc(i64 9)
	%empty_cap = bitcast i8* %empty_raw to i32*
  store i32 0, i32* %empty_cap
	%empty_ref = getelementptr inbounds i8, i8* %empty_raw, i64 4
	%empty_ref32 = bitcast i8* %empty_ref to i32*
  store i32 1, i32* %empty_ref32
	%empty = getelementptr inbounds i8, i8* %empty_raw, i64 8
	store i8 0, i8* %empty
	ret i8* %empty
alloc:
	%alloc_size = add i64 %len, 9
	%raw = call i8* @malloc(i64 %alloc_size)
	%cap_ptr = bitcast i8* %raw to i32*
	%capacity = trunc i64 %len to i32
	store i32 %capacity, i32* %cap_ptr
	%ref_ptr = getelementptr inbounds i8, i8* %raw, i64 4
	%ref_ptr32 = bitcast i8* %ref_ptr to i32*
  store i32 1, i32* %ref_ptr32
	%buf = getelementptr inbounds i8, i8* %raw, i64 8
  call i8* @memcpy(i8* %buf, i8* %ptr, i64 %len)
  %null_ptr = getelementptr inbounds i8, i8* %buf, i64 %len
  store i8 0, i8* %null_ptr
  ret i8* %buf
}

; ------------------------------------------------------------------------------
; Hash Map Runtime Types & Functions
; ------------------------------------------------------------------------------

%struct.__hike_map_entry = type { i64, i64, i64, %struct.__hike_map_entry* }
%struct.__hike_map = type { %struct.__hike_map_entry**, i64, i64, i64 }
%struct.__hike_string_key = type { i8*, i64 }

; Return the visible start of a string view. The offset uses the same encoded
; representation as the Hike fat-string value, so literals and borrowed views
; are normalized at one runtime boundary.
define internal i8* @__hike_string_start(i8* %base, i32 %encoded_offset) {
entry:
  %sign = ashr i32 %encoded_offset, 31
  %offset = xor i32 %encoded_offset, %sign
  %start = getelementptr inbounds i8, i8* %base, i32 %offset
  ret i8* %start
}

; Create an owned descriptor for a length-aware Hike string view.  The bytes
; themselves remain owned by the string value; only the descriptor is stored
; as the map key.
define internal i64 @__hike_string_key(i8* %ptr, i64 %len) {
entry:
  %raw = call i8* @malloc(i64 16)
  %key = bitcast i8* %raw to %struct.__hike_string_key*
  %p_ptr = getelementptr inbounds %struct.__hike_string_key, %struct.__hike_string_key* %key, i32 0, i32 0
  store i8* %ptr, i8** %p_ptr
  %p_len = getelementptr inbounds %struct.__hike_string_key, %struct.__hike_string_key* %key, i32 0, i32 1
  store i64 %len, i64* %p_len
  %token = ptrtoint i8* %raw to i64
  ret i64 %token
}

define internal i8* @__hike_map_key_ptr(i64 %token) {
entry:
  %raw = inttoptr i64 %token to i8*
  %key = bitcast i8* %raw to %struct.__hike_string_key*
  %p = getelementptr inbounds %struct.__hike_string_key, %struct.__hike_string_key* %key, i32 0, i32 0
  %ptr = load i8*, i8** %p
  ret i8* %ptr
}

define internal i64 @__hike_map_key_len(i64 %token) {
entry:
  %raw = inttoptr i64 %token to i8*
  %key = bitcast i8* %raw to %struct.__hike_string_key*
  %p = getelementptr inbounds %struct.__hike_string_key, %struct.__hike_string_key* %key, i32 0, i32 1
  %len = load i64, i64* %p
  ret i64 %len
}

; 文字列 FNV-1a ハッシュ算出
define internal i64 @__hike_hash_str(i8* %key_raw) {
entry:
  %null_chk = icmp eq i8* %key_raw, null
  br i1 %null_chk, label %ret_zero, label %loop_init
ret_zero:
  ret i64 0
loop_init:
  %key = bitcast i8* %key_raw to %struct.__hike_string_key*
  %p_data = getelementptr inbounds %struct.__hike_string_key, %struct.__hike_string_key* %key, i32 0, i32 0
  %data = load i8*, i8** %p_data
  %p_len = getelementptr inbounds %struct.__hike_string_key, %struct.__hike_string_key* %key, i32 0, i32 1
  %len = load i64, i64* %p_len
  br label %loop.cond
loop.cond:
  %h = phi i64 [ -3750763034362895579, %loop_init ], [ %h.next, %loop.body ]
  %i = phi i64 [ 0, %loop_init ], [ %i.next, %loop.body ]
  %ptr = getelementptr inbounds i8, i8* %data, i64 %i
  %done = icmp uge i64 %i, %len
  br i1 %done, label %loop.end, label %loop.body
loop.body:
  %ch = load i8, i8* %ptr
  %ch.zext = zext i8 %ch to i64
  %h.xor = xor i64 %h, %ch.zext
  %h.next = mul i64 %h.xor, 1099511628211
  %i.next = add i64 %i, 1
  br label %loop.cond
loop.end:
  ret i64 %h
}

; マップキーの一致判定
define internal i1 @__hike_map_key_eq(i64 %k1, i64 %k2, i64 %is_str) {
entry:
  %is_s = icmp ne i64 %is_str, 0
  br i1 %is_s, label %check_str, label %check_int
check_int:
  %eq_int = icmp eq i64 %k1, %k2
  ret i1 %eq_int
check_str:
  %p1 = inttoptr i64 %k1 to i8*
  %p2 = inttoptr i64 %k2 to i8*
  %n1 = icmp eq i8* %p1, null
  %n2 = icmp eq i8* %p2, null
  %either_null = or i1 %n1, %n2
  br i1 %either_null, label %check_both_null, label %load_keys
check_both_null:
  %both_null = and i1 %n1, %n2
  ret i1 %both_null
load_keys:
  %key1 = bitcast i8* %p1 to %struct.__hike_string_key*
  %key2 = bitcast i8* %p2 to %struct.__hike_string_key*
  %d1p = getelementptr inbounds %struct.__hike_string_key, %struct.__hike_string_key* %key1, i32 0, i32 0
  %d2p = getelementptr inbounds %struct.__hike_string_key, %struct.__hike_string_key* %key2, i32 0, i32 0
  %d1 = load i8*, i8** %d1p
  %d2 = load i8*, i8** %d2p
  %l1p = getelementptr inbounds %struct.__hike_string_key, %struct.__hike_string_key* %key1, i32 0, i32 1
  %l2p = getelementptr inbounds %struct.__hike_string_key, %struct.__hike_string_key* %key2, i32 0, i32 1
  %l1 = load i64, i64* %l1p
  %l2 = load i64, i64* %l2p
  %len_eq = icmp eq i64 %l1, %l2
  br i1 %len_eq, label %compare_bytes, label %ret_false
compare_bytes:
  %res = call i32 @memcmp(i8* %d1, i8* %d2, i64 %l1)
  %is_z = icmp eq i32 %res, 0
  ret i1 %is_z
ret_false:
  ret i1 false
}

; マップの新規生成
define internal %struct.__hike_map* @__hike_map_create(i64 %cap, i64 %is_str) {
entry:
  %raw = call i8* @malloc(i64 32)
  %m = bitcast i8* %raw to %struct.__hike_map*
  %buckets_raw = call i8* @calloc(i64 16, i64 8)
  %buckets = bitcast i8* %buckets_raw to %struct.__hike_map_entry**
  %p_b = getelementptr inbounds %struct.__hike_map, %struct.__hike_map* %m, i32 0, i32 0
  store %struct.__hike_map_entry** %buckets, %struct.__hike_map_entry*** %p_b
  %p_nb = getelementptr inbounds %struct.__hike_map, %struct.__hike_map* %m, i32 0, i32 1
  store i64 16, i64* %p_nb
  %p_len = getelementptr inbounds %struct.__hike_map, %struct.__hike_map* %m, i32 0, i32 2
  store i64 0, i64* %p_len
  %p_str = getelementptr inbounds %struct.__hike_map, %struct.__hike_map* %m, i32 0, i32 3
  store i64 %is_str, i64* %p_str
  ret %struct.__hike_map* %m
}

; mapped persistence keeps a private in-process snapshot of a map.  The map
; entries are copied so updates to the live map after serialization do not
; mutate the saved snapshot.  Boxed values remain owned by their existing
; heap objects and are restored together with the cloned entry table.
define internal %struct.__hike_map* @__hike_mapped_map_clone(%struct.__hike_map* %src) {
entry:
  %is_null = icmp eq %struct.__hike_map* %src, null
  br i1 %is_null, label %null_ret, label %alloc_map
null_ret:
  ret %struct.__hike_map* null
alloc_map:
  %raw = call i8* @malloc(i64 32)
  %dst = bitcast i8* %raw to %struct.__hike_map*
  %src_b_p = getelementptr inbounds %struct.__hike_map, %struct.__hike_map* %src, i32 0, i32 0
  %src_b = load %struct.__hike_map_entry**, %struct.__hike_map_entry*** %src_b_p
  %src_nb_p = getelementptr inbounds %struct.__hike_map, %struct.__hike_map* %src, i32 0, i32 1
  %src_nb = load i64, i64* %src_nb_p
  %src_len_p = getelementptr inbounds %struct.__hike_map, %struct.__hike_map* %src, i32 0, i32 2
  %src_len = load i64, i64* %src_len_p
  %src_str_p = getelementptr inbounds %struct.__hike_map, %struct.__hike_map* %src, i32 0, i32 3
  %src_str = load i64, i64* %src_str_p
  %dst_b_raw = call i8* @calloc(i64 %src_nb, i64 8)
  %dst_b = bitcast i8* %dst_b_raw to %struct.__hike_map_entry**
  %dst_b_p = getelementptr inbounds %struct.__hike_map, %struct.__hike_map* %dst, i32 0, i32 0
  store %struct.__hike_map_entry** %dst_b, %struct.__hike_map_entry*** %dst_b_p
  %dst_nb_p = getelementptr inbounds %struct.__hike_map, %struct.__hike_map* %dst, i32 0, i32 1
  store i64 %src_nb, i64* %dst_nb_p
  %dst_len_p = getelementptr inbounds %struct.__hike_map, %struct.__hike_map* %dst, i32 0, i32 2
  store i64 %src_len, i64* %dst_len_p
  %dst_str_p = getelementptr inbounds %struct.__hike_map, %struct.__hike_map* %dst, i32 0, i32 3
  store i64 %src_str, i64* %dst_str_p
  br label %bucket_cond
bucket_cond:
  %bucket = phi i64 [ 0, %alloc_map ], [ %bucket_next, %bucket_next_block ]
  %bucket_done = icmp uge i64 %bucket, %src_nb
  br i1 %bucket_done, label %done, label %bucket_body
bucket_body:
  %src_head_p = getelementptr inbounds %struct.__hike_map_entry*, %struct.__hike_map_entry** %src_b, i64 %bucket
  %src_head = load %struct.__hike_map_entry*, %struct.__hike_map_entry** %src_head_p
  %dst_head_p = getelementptr inbounds %struct.__hike_map_entry*, %struct.__hike_map_entry** %dst_b, i64 %bucket
  br label %entry_cond
entry_cond:
  %cur = phi %struct.__hike_map_entry* [ %src_head, %bucket_body ], [ %src_next, %entry_next ]
  %dst_prev = phi %struct.__hike_map_entry* [ null, %bucket_body ], [ %copy, %entry_next ]
  %has_cur = icmp ne %struct.__hike_map_entry* %cur, null
  br i1 %has_cur, label %entry_copy, label %entry_done
entry_copy:
  %raw_entry = call i8* @malloc(i64 32)
  %copy = bitcast i8* %raw_entry to %struct.__hike_map_entry*
  %cur_hash_p = getelementptr inbounds %struct.__hike_map_entry, %struct.__hike_map_entry* %cur, i32 0, i32 0
  %cur_hash = load i64, i64* %cur_hash_p
  %copy_hash_p = getelementptr inbounds %struct.__hike_map_entry, %struct.__hike_map_entry* %copy, i32 0, i32 0
  store i64 %cur_hash, i64* %copy_hash_p
  %cur_key_p = getelementptr inbounds %struct.__hike_map_entry, %struct.__hike_map_entry* %cur, i32 0, i32 1
  %cur_key = load i64, i64* %cur_key_p
  %copy_key_p = getelementptr inbounds %struct.__hike_map_entry, %struct.__hike_map_entry* %copy, i32 0, i32 1
  store i64 %cur_key, i64* %copy_key_p
  %cur_val_p = getelementptr inbounds %struct.__hike_map_entry, %struct.__hike_map_entry* %cur, i32 0, i32 2
  %cur_val = load i64, i64* %cur_val_p
  %copy_val_p = getelementptr inbounds %struct.__hike_map_entry, %struct.__hike_map_entry* %copy, i32 0, i32 2
  store i64 %cur_val, i64* %copy_val_p
  %copy_next_p = getelementptr inbounds %struct.__hike_map_entry, %struct.__hike_map_entry* %copy, i32 0, i32 3
  store %struct.__hike_map_entry* null, %struct.__hike_map_entry** %copy_next_p
  %has_prev = icmp ne %struct.__hike_map_entry* %dst_prev, null
  br i1 %has_prev, label %link_prev, label %link_head
link_prev:
  %prev_next_p = getelementptr inbounds %struct.__hike_map_entry, %struct.__hike_map_entry* %dst_prev, i32 0, i32 3
  store %struct.__hike_map_entry* %copy, %struct.__hike_map_entry** %prev_next_p
  br label %entry_next
link_head:
  store %struct.__hike_map_entry* %copy, %struct.__hike_map_entry** %dst_head_p
  br label %entry_next
entry_next:
  %src_next_p = getelementptr inbounds %struct.__hike_map_entry, %struct.__hike_map_entry* %cur, i32 0, i32 3
  %src_next = load %struct.__hike_map_entry*, %struct.__hike_map_entry** %src_next_p
  br label %entry_cond
entry_done:
  br label %bucket_next_block
bucket_next_block:
  %bucket_next = add i64 %bucket, 1
  br label %bucket_cond
done:
  ret %struct.__hike_map* %dst
}

; マップバケットの拡張と再ハッシュ
define internal void @__hike_map_grow(%struct.__hike_map* %m) {
entry:
  %p_nb = getelementptr inbounds %struct.__hike_map, %struct.__hike_map* %m, i32 0, i32 1
  %old_nb = load i64, i64* %p_nb
  %p_b = getelementptr inbounds %struct.__hike_map, %struct.__hike_map* %m, i32 0, i32 0
  %old_b = load %struct.__hike_map_entry**, %struct.__hike_map_entry*** %p_b
  %new_nb = mul i64 %old_nb, 2
  %new_raw = call i8* @calloc(i64 %new_nb, i64 8)
  %new_b = bitcast i8* %new_raw to %struct.__hike_map_entry**
  br label %loop.i
loop.i:
  %i = phi i64 [ 0, %entry ], [ %i.next, %loop.i.inc ]
  %cmp.i = icmp slt i64 %i, %old_nb
  br i1 %cmp.i, label %loop.entry.init, label %loop.i.done
loop.entry.init:
  %p_cur_head = getelementptr inbounds %struct.__hike_map_entry*, %struct.__hike_map_entry** %old_b, i64 %i
  %head = load %struct.__hike_map_entry*, %struct.__hike_map_entry** %p_cur_head
  br label %loop.entry
loop.entry:
  %cur = phi %struct.__hike_map_entry* [ %head, %loop.entry.init ], [ %nxt, %loop.entry.body ]
  %has_cur = icmp ne %struct.__hike_map_entry* %cur, null
  br i1 %has_cur, label %loop.entry.body, label %loop.i.inc
loop.entry.body:
  %p_nxt = getelementptr inbounds %struct.__hike_map_entry, %struct.__hike_map_entry* %cur, i32 0, i32 3
  %nxt = load %struct.__hike_map_entry*, %struct.__hike_map_entry** %p_nxt
  %p_hash = getelementptr inbounds %struct.__hike_map_entry, %struct.__hike_map_entry* %cur, i32 0, i32 0
  %h_val = load i64, i64* %p_hash
  %h_pos = and i64 %h_val, 9223372036854775807
  %new_idx = urem i64 %h_pos, %new_nb
  %p_new_slot = getelementptr inbounds %struct.__hike_map_entry*, %struct.__hike_map_entry** %new_b, i64 %new_idx
  %existing = load %struct.__hike_map_entry*, %struct.__hike_map_entry** %p_new_slot
  store %struct.__hike_map_entry* %existing, %struct.__hike_map_entry** %p_nxt
  store %struct.__hike_map_entry* %cur, %struct.__hike_map_entry** %p_new_slot
  br label %loop.entry
loop.i.inc:
  %i.next = add i64 %i, 1
  br label %loop.i
loop.i.done:
  %old_b_raw = bitcast %struct.__hike_map_entry** %old_b to i8*
  call void @free(i8* %old_b_raw)
  store %struct.__hike_map_entry** %new_b, %struct.__hike_map_entry*** %p_b
  store i64 %new_nb, i64* %p_nb
  ret void
}

; マップへのキー・値格納
define internal void @__hike_map_set(%struct.__hike_map* %m, i64 %key, i64 %val) {
entry:
  %null_m = icmp eq %struct.__hike_map* %m, null
  br i1 %null_m, label %ret_void, label %check_grow
ret_void:
  ret void
check_grow:
  %p_len = getelementptr inbounds %struct.__hike_map, %struct.__hike_map* %m, i32 0, i32 2
  %cur_len = load i64, i64* %p_len
  %p_nb = getelementptr inbounds %struct.__hike_map, %struct.__hike_map* %m, i32 0, i32 1
  %nb = load i64, i64* %p_nb
  %limit = mul i64 %nb, 3
  %limit_div = sdiv i64 %limit, 4
  %needs_grow = icmp sge i64 %cur_len, %limit_div
  br i1 %needs_grow, label %do_grow, label %do_hash
do_grow:
  call void @__hike_map_grow(%struct.__hike_map* %m)
  br label %do_hash
do_hash:
  %p_str = getelementptr inbounds %struct.__hike_map, %struct.__hike_map* %m, i32 0, i32 3
  %is_str = load i64, i64* %p_str
  %is_s = icmp ne i64 %is_str, 0
  br i1 %is_s, label %hash_str, label %hash_int
hash_str:
  %k_ptr = inttoptr i64 %key to i8*
  %h_s = call i64 @__hike_hash_str(i8* %k_ptr)
  br label %lookup
hash_int:
  br label %lookup
lookup:
  %hash = phi i64 [ %h_s, %hash_str ], [ %key, %hash_int ]
  %p_nb_2 = getelementptr inbounds %struct.__hike_map, %struct.__hike_map* %m, i32 0, i32 1
  %nb_cur = load i64, i64* %p_nb_2
  %h_pos = and i64 %hash, 9223372036854775807
  %idx = urem i64 %h_pos, %nb_cur
  %p_b = getelementptr inbounds %struct.__hike_map, %struct.__hike_map* %m, i32 0, i32 0
  %buckets = load %struct.__hike_map_entry**, %struct.__hike_map_entry*** %p_b
  %p_head = getelementptr inbounds %struct.__hike_map_entry*, %struct.__hike_map_entry** %buckets, i64 %idx
  %head = load %struct.__hike_map_entry*, %struct.__hike_map_entry** %p_head
  br label %search.entry
search.entry:
  %cur = phi %struct.__hike_map_entry* [ %head, %lookup ], [ %cur.next, %search.next ]
  %has_entry = icmp ne %struct.__hike_map_entry* %cur, null
  br i1 %has_entry, label %search.body, label %insert_new
search.body:
  %p_ehash = getelementptr inbounds %struct.__hike_map_entry, %struct.__hike_map_entry* %cur, i32 0, i32 0
  %ehash = load i64, i64* %p_ehash
  %hash_match = icmp eq i64 %ehash, %hash
  br i1 %hash_match, label %search.key_check, label %search.next
search.key_check:
  %p_ekey = getelementptr inbounds %struct.__hike_map_entry, %struct.__hike_map_entry* %cur, i32 0, i32 1
  %ekey = load i64, i64* %p_ekey
  %key_match = call i1 @__hike_map_key_eq(i64 %ekey, i64 %key, i64 %is_str)
  br i1 %key_match, label %update_val, label %search.next
update_val:
  %p_eval = getelementptr inbounds %struct.__hike_map_entry, %struct.__hike_map_entry* %cur, i32 0, i32 2
  store i64 %val, i64* %p_eval
  ret void
search.next:
  %p_enext = getelementptr inbounds %struct.__hike_map_entry, %struct.__hike_map_entry* %cur, i32 0, i32 3
  %cur.next = load %struct.__hike_map_entry*, %struct.__hike_map_entry** %p_enext
  br label %search.entry
insert_new:
  %new_entry_raw = call i8* @malloc(i64 32)
  %new_e = bitcast i8* %new_entry_raw to %struct.__hike_map_entry*
  %np_hash = getelementptr inbounds %struct.__hike_map_entry, %struct.__hike_map_entry* %new_e, i32 0, i32 0
  store i64 %hash, i64* %np_hash
  %np_key = getelementptr inbounds %struct.__hike_map_entry, %struct.__hike_map_entry* %new_e, i32 0, i32 1
  store i64 %key, i64* %np_key
  %np_val = getelementptr inbounds %struct.__hike_map_entry, %struct.__hike_map_entry* %new_e, i32 0, i32 2
  store i64 %val, i64* %np_val
  %np_next = getelementptr inbounds %struct.__hike_map_entry, %struct.__hike_map_entry* %new_e, i32 0, i32 3
  %cur_head = load %struct.__hike_map_entry*, %struct.__hike_map_entry** %p_head
  store %struct.__hike_map_entry* %cur_head, %struct.__hike_map_entry** %np_next
  store %struct.__hike_map_entry* %new_e, %struct.__hike_map_entry** %p_head
  %new_len = add i64 %cur_len, 1
  store i64 %new_len, i64* %p_len
  ret void
}

; マップからの値取得
define internal i1 @__hike_map_get(%struct.__hike_map* %m, i64 %key, i64* %out_val) {
entry:
  %null_m = icmp eq %struct.__hike_map* %m, null
  br i1 %null_m, label %ret_not_found, label %do_lookup
ret_not_found:
  store i64 0, i64* %out_val
  ret i1 false
do_lookup:
  %p_str = getelementptr inbounds %struct.__hike_map, %struct.__hike_map* %m, i32 0, i32 3
  %is_str = load i64, i64* %p_str
  %is_s = icmp ne i64 %is_str, 0
  br i1 %is_s, label %hash_str, label %hash_int
hash_str:
  %k_ptr = inttoptr i64 %key to i8*
  %h_s = call i64 @__hike_hash_str(i8* %k_ptr)
  br label %search_init
hash_int:
  br label %search_init
search_init:
  %hash = phi i64 [ %h_s, %hash_str ], [ %key, %hash_int ]
  %p_nb = getelementptr inbounds %struct.__hike_map, %struct.__hike_map* %m, i32 0, i32 1
  %nb = load i64, i64* %p_nb
  %h_pos = and i64 %hash, 9223372036854775807
  %idx = urem i64 %h_pos, %nb
  %p_b = getelementptr inbounds %struct.__hike_map, %struct.__hike_map* %m, i32 0, i32 0
  %buckets = load %struct.__hike_map_entry**, %struct.__hike_map_entry*** %p_b
  %p_head = getelementptr inbounds %struct.__hike_map_entry*, %struct.__hike_map_entry** %buckets, i64 %idx
  %head = load %struct.__hike_map_entry*, %struct.__hike_map_entry** %p_head
  br label %search.entry
search.entry:
  %cur = phi %struct.__hike_map_entry* [ %head, %search_init ], [ %cur.next, %search.next ]
  %has_entry = icmp ne %struct.__hike_map_entry* %cur, null
  br i1 %has_entry, label %search.body, label %ret_not_found
search.body:
  %p_ehash = getelementptr inbounds %struct.__hike_map_entry, %struct.__hike_map_entry* %cur, i32 0, i32 0
  %ehash = load i64, i64* %p_ehash
  %hash_match = icmp eq i64 %ehash, %hash
  br i1 %hash_match, label %search.key_check, label %search.next
search.key_check:
  %p_ekey = getelementptr inbounds %struct.__hike_map_entry, %struct.__hike_map_entry* %cur, i32 0, i32 1
  %ekey = load i64, i64* %p_ekey
  %key_match = call i1 @__hike_map_key_eq(i64 %ekey, i64 %key, i64 %is_str)
  br i1 %key_match, label %found, label %search.next
found:
  %p_eval = getelementptr inbounds %struct.__hike_map_entry, %struct.__hike_map_entry* %cur, i32 0, i32 2
  %val = load i64, i64* %p_eval
  store i64 %val, i64* %out_val
  ret i1 true
search.next:
  %p_enext = getelementptr inbounds %struct.__hike_map_entry, %struct.__hike_map_entry* %cur, i32 0, i32 3
  %cur.next = load %struct.__hike_map_entry*, %struct.__hike_map_entry** %p_enext
  br label %search.entry
}

; Boxed map lookup. A missing key receives the caller-provided zero value
; pointer so composite values can be read without dereferencing null.
define internal void @__hike_map_get_boxed(%struct.__hike_map* %m, i64 %key, i64* %out_val, i8* %zero_ptr) {
entry:
  %found = call i1 @__hike_map_get(%struct.__hike_map* %m, i64 %key, i64* %out_val)
  br i1 %found, label %done, label %missing
missing:
  %zero_val = ptrtoint i8* %zero_ptr to i64
  store i64 %zero_val, i64* %out_val
  br label %done
done:
  ret void
}

define internal i1 @__hike_map_get_boxed_ok(%struct.__hike_map* %m, i64 %key, i64* %out_val, i8* %zero_ptr) {
entry:
  %found = call i1 @__hike_map_get(%struct.__hike_map* %m, i64 %key, i64* %out_val)
  br i1 %found, label %done, label %missing
missing:
  %zero_val = ptrtoint i8* %zero_ptr to i64
  store i64 %zero_val, i64* %out_val
  br label %done
done:
  ret i1 %found
}

; String-key map ABI. The lookup boundary receives the visible start pointer
; and length directly; only the stored entry uses an owned key descriptor.
define internal void @__hike_map_set_str(%struct.__hike_map* %m, i8* %ptr, i64 %len, i64 %val) {
entry:
  %key = call i64 @__hike_string_key(i8* %ptr, i64 %len)
  call void @__hike_map_set(%struct.__hike_map* %m, i64 %key, i64 %val)
  ret void
}

define internal i1 @__hike_map_get_str(%struct.__hike_map* %m, i8* %ptr, i64 %len, i64* %out_val) {
entry:
  %key = alloca %struct.__hike_string_key
  %key_ptr = getelementptr inbounds %struct.__hike_string_key, %struct.__hike_string_key* %key, i32 0, i32 0
  store i8* %ptr, i8** %key_ptr
  %key_len = getelementptr inbounds %struct.__hike_string_key, %struct.__hike_string_key* %key, i32 0, i32 1
  store i64 %len, i64* %key_len
  %token = ptrtoint %struct.__hike_string_key* %key to i64
  %found = call i1 @__hike_map_get(%struct.__hike_map* %m, i64 %token, i64* %out_val)
  ret i1 %found
}

define internal void @__hike_map_get_boxed_str(%struct.__hike_map* %m, i8* %ptr, i64 %len, i64* %out_val, i8* %zero_ptr) {
entry:
  %found = call i1 @__hike_map_get_str(%struct.__hike_map* %m, i8* %ptr, i64 %len, i64* %out_val)
  br i1 %found, label %done, label %missing
missing:
  %zero_val = ptrtoint i8* %zero_ptr to i64
  store i64 %zero_val, i64* %out_val
  br label %done
done:
  ret void
}

define internal i1 @__hike_map_get_boxed_str_ok(%struct.__hike_map* %m, i8* %ptr, i64 %len, i64* %out_val, i8* %zero_ptr) {
entry:
  %found = call i1 @__hike_map_get_str(%struct.__hike_map* %m, i8* %ptr, i64 %len, i64* %out_val)
  br i1 %found, label %done, label %missing
missing:
  %zero_val = ptrtoint i8* %zero_ptr to i64
  store i64 %zero_val, i64* %out_val
  br label %done
done:
  ret i1 %found
}

define internal void @__hike_map_delete_str(%struct.__hike_map* %m, i8* %ptr, i64 %len) {
entry:
  %key = alloca %struct.__hike_string_key
  %key_ptr = getelementptr inbounds %struct.__hike_string_key, %struct.__hike_string_key* %key, i32 0, i32 0
  store i8* %ptr, i8** %key_ptr
  %key_len = getelementptr inbounds %struct.__hike_string_key, %struct.__hike_string_key* %key, i32 0, i32 1
  store i64 %len, i64* %key_len
  %token = ptrtoint %struct.__hike_string_key* %key to i64
  call void @__hike_map_delete(%struct.__hike_map* %m, i64 %token)
  ret void
}

define internal i32 @__hike_iface_typeid(i8* %itab) {
entry:
  %is_null = icmp eq i8* %itab, null
  br i1 %is_null, label %missing, label %present
missing:
  ret i32 0
present:
  %type_ptr = bitcast i8* %itab to i32*
  %type_id = load i32, i32* %type_ptr
  ret i32 %type_id
}

; マップ要素の削除
define internal void @__hike_map_delete(%struct.__hike_map* %m, i64 %key) {
entry:
  %null_m = icmp eq %struct.__hike_map* %m, null
  br i1 %null_m, label %ret_void, label %do_del
ret_void:
  ret void
do_del:
  %p_str = getelementptr inbounds %struct.__hike_map, %struct.__hike_map* %m, i32 0, i32 3
  %is_str = load i64, i64* %p_str
  %is_s = icmp ne i64 %is_str, 0
  br i1 %is_s, label %hash_str, label %hash_int
hash_str:
  %k_ptr = inttoptr i64 %key to i8*
  %h_s = call i64 @__hike_hash_str(i8* %k_ptr)
  br label %search_init
hash_int:
  br label %search_init
search_init:
  %hash = phi i64 [ %h_s, %hash_str ], [ %key, %hash_int ]
  %p_nb = getelementptr inbounds %struct.__hike_map, %struct.__hike_map* %m, i32 0, i32 1
  %nb = load i64, i64* %p_nb
  %h_pos = and i64 %hash, 9223372036854775807
  %idx = urem i64 %h_pos, %nb
  %p_b = getelementptr inbounds %struct.__hike_map, %struct.__hike_map* %m, i32 0, i32 0
  %buckets = load %struct.__hike_map_entry**, %struct.__hike_map_entry*** %p_b
  %p_head = getelementptr inbounds %struct.__hike_map_entry*, %struct.__hike_map_entry** %buckets, i64 %idx
  %head = load %struct.__hike_map_entry*, %struct.__hike_map_entry** %p_head
  br label %search.entry
search.entry:
  %prev = phi %struct.__hike_map_entry* [ null, %search_init ], [ %cur, %search.next ]
  %cur = phi %struct.__hike_map_entry* [ %head, %search_init ], [ %cur.next, %search.next ]
  %has_entry = icmp ne %struct.__hike_map_entry* %cur, null
  br i1 %has_entry, label %search.body, label %ret_void
search.body:
  %p_ehash = getelementptr inbounds %struct.__hike_map_entry, %struct.__hike_map_entry* %cur, i32 0, i32 0
  %ehash = load i64, i64* %p_ehash
  %hash_match = icmp eq i64 %ehash, %hash
  br i1 %hash_match, label %search.key_check, label %search.next
search.key_check:
  %p_ekey = getelementptr inbounds %struct.__hike_map_entry, %struct.__hike_map_entry* %cur, i32 0, i32 1
  %ekey = load i64, i64* %p_ekey
  %key_match = call i1 @__hike_map_key_eq(i64 %ekey, i64 %key, i64 %is_str)
  br i1 %key_match, label %do_unlink, label %search.next
do_unlink:
  %p_enext = getelementptr inbounds %struct.__hike_map_entry, %struct.__hike_map_entry* %cur, i32 0, i32 3
  %nxt = load %struct.__hike_map_entry*, %struct.__hike_map_entry** %p_enext
  %has_prev = icmp ne %struct.__hike_map_entry* %prev, null
  br i1 %has_prev, label %unlink_prev, label %unlink_head
unlink_prev:
  %p_pnext = getelementptr inbounds %struct.__hike_map_entry, %struct.__hike_map_entry* %prev, i32 0, i32 3
  store %struct.__hike_map_entry* %nxt, %struct.__hike_map_entry** %p_pnext
  br label %after_unlink
unlink_head:
  store %struct.__hike_map_entry* %nxt, %struct.__hike_map_entry** %p_head
  br label %after_unlink
after_unlink:
  %cur_raw = bitcast %struct.__hike_map_entry* %cur to i8*
  call void @free(i8* %cur_raw)
  %p_len = getelementptr inbounds %struct.__hike_map, %struct.__hike_map* %m, i32 0, i32 2
  %cur_len = load i64, i64* %p_len
  %new_len = sub i64 %cur_len, 1
  store i64 %new_len, i64* %p_len
  ret void
search.next:
  %p_enext2 = getelementptr inbounds %struct.__hike_map_entry, %struct.__hike_map_entry* %cur, i32 0, i32 3
  %cur.next = load %struct.__hike_map_entry*, %struct.__hike_map_entry** %p_enext2
  br label %search.entry
}

; マップ要素数の取得
define internal i64 @__hike_map_len(%struct.__hike_map* %m) {
entry:
  %null_m = icmp eq %struct.__hike_map* %m, null
  br i1 %null_m, label %ret_zero, label %get_len
ret_zero:
  ret i64 0
get_len:
  %p_len = getelementptr inbounds %struct.__hike_map, %struct.__hike_map* %m, i32 0, i32 2
  %l = load i64, i64* %p_len
  ret i64 %l
}

; ------------------------------------------------------------------------------
; Attributes
; ------------------------------------------------------------------------------

; Compatibility wrappers keep the source-level MapType pointer ABI stable while
; routing 64-bit lowering through the compact representation above.
define internal %struct.__hike_map* @__hike_cdict_create(i64 %cap, i64 %is_str) {
entry:
  %m = call %struct.__hike_compact_map* @__hike_compact_map_create(i64 %cap, i64 %is_str)
  %state_raw = bitcast %struct.__hike_compact_map* %m to i8*
  %legacy_raw = getelementptr i8, i8* %state_raw, i64 -32
  %legacy = bitcast i8* %legacy_raw to %struct.__hike_map*
  ret %struct.__hike_map* %legacy
}

define internal %struct.__hike_compact_map* @__hike_cdict_state(%struct.__hike_map* %m) {
entry:
  %raw = bitcast %struct.__hike_map* %m to i8*
  %state_raw = getelementptr i8, i8* %raw, i64 32
  %state = bitcast i8* %state_raw to %struct.__hike_compact_map*
  ret %struct.__hike_compact_map* %state
}

define internal void @__hike_cdict_set(%struct.__hike_map* %m, i64 %key, i64 %value) {
entry:
  %compact = call %struct.__hike_compact_map* @__hike_cdict_state(%struct.__hike_map* %m)
  call void @__hike_compact_map_set(%struct.__hike_compact_map* %compact, i64 %key, i64 %key, i64 %value)
  ret void
}

define internal i1 @__hike_cdict_get(%struct.__hike_map* %m, i64 %key, i64* %out) {
entry:
  %null_m = icmp eq %struct.__hike_map* %m, null
  br i1 %null_m, label %not_found, label %lookup
lookup:
  %compact = call %struct.__hike_compact_map* @__hike_cdict_state(%struct.__hike_map* %m)
  %found = call i1 @__hike_compact_map_get(%struct.__hike_compact_map* %compact, i64 %key, i64 %key, i64* %out)
  ret i1 %found
not_found:
  store i64 0, i64* %out
  ret i1 false
}

define internal void @__hike_cdict_set_str(%struct.__hike_map* %m, i8* %ptr, i64 %len, i64 %value) {
entry:
  %key = call i64 @__hike_string_key(i8* %ptr, i64 %len)
  %key_ptr = inttoptr i64 %key to i8*
  %hash = call i64 @__hike_hash_str(i8* %key_ptr)
  %compact = call %struct.__hike_compact_map* @__hike_cdict_state(%struct.__hike_map* %m)
  call void @__hike_compact_map_set(%struct.__hike_compact_map* %compact, i64 %key, i64 %hash, i64 %value)
  ret void
}

define internal void @__hike_cdict_set_str_hash(%struct.__hike_map* %m, i8* %ptr, i64 %len, i64 %hash, i64 %value) {
entry:
  %key = call i64 @__hike_string_key(i8* %ptr, i64 %len)
  %compact = call %struct.__hike_compact_map* @__hike_cdict_state(%struct.__hike_map* %m)
  call void @__hike_compact_map_set(%struct.__hike_compact_map* %compact, i64 %key, i64 %hash, i64 %value)
  ret void
}

define internal i1 @__hike_cdict_get_str(%struct.__hike_map* %m, i8* %ptr, i64 %len, i64* %out) {
entry:
  %null_m = icmp eq %struct.__hike_map* %m, null
  br i1 %null_m, label %not_found, label %lookup
lookup:
  %key = alloca %struct.__hike_string_key
  %p_ptr = getelementptr %struct.__hike_string_key, %struct.__hike_string_key* %key, i32 0, i32 0
  store i8* %ptr, i8** %p_ptr
  %p_len = getelementptr %struct.__hike_string_key, %struct.__hike_string_key* %key, i32 0, i32 1
  store i64 %len, i64* %p_len
  %token = ptrtoint %struct.__hike_string_key* %key to i64
  %hash = call i64 @__hike_hash_str(i8* %key)
  %compact = call %struct.__hike_compact_map* @__hike_cdict_state(%struct.__hike_map* %m)
  %found = call i1 @__hike_compact_map_get(%struct.__hike_compact_map* %compact, i64 %token, i64 %hash, i64* %out)
  ret i1 %found
not_found:
  store i64 0, i64* %out
  ret i1 false
}

%struct.__hike_compact_map_entry = type { i64, i64, i64, i64, i64 }
%struct.__hike_compact_map = type { i64*, %struct.__hike_compact_map_entry*, i64, i64, i64, i64, i64 }

define internal i1 @__hike_cdict_get_index(%struct.__hike_map* %m, i64 %index, i64* %out) {
entry:
  %compact = call %struct.__hike_compact_map* @__hike_cdict_state(%struct.__hike_map* %m)
  %p_entries = getelementptr %struct.__hike_compact_map, %struct.__hike_compact_map* %compact, i32 0, i32 1
  %entries = load %struct.__hike_compact_map_entry*, %struct.__hike_compact_map_entry** %p_entries
  %entry_ptr = getelementptr %struct.__hike_compact_map_entry, %struct.__hike_compact_map_entry* %entries, i64 %index
  %p_state = getelementptr %struct.__hike_compact_map_entry, %struct.__hike_compact_map_entry* %entry_ptr, i32 0, i32 4
  %state = load i64, i64* %p_state
  %live = icmp eq i64 %state, 1
  br i1 %live, label %found, label %missing
found:
  %p_value = getelementptr %struct.__hike_compact_map_entry, %struct.__hike_compact_map_entry* %entry_ptr, i32 0, i32 2
  %value = load i64, i64* %p_value
  store i64 %value, i64* %out
  ret i1 true
missing:
  store i64 0, i64* %out
  ret i1 false
}

define internal void @__hike_cdict_set_index(%struct.__hike_map* %m, i64 %index, i64 %value) {
entry:
  %compact = call %struct.__hike_compact_map* @__hike_cdict_state(%struct.__hike_map* %m)
  %p_entries = getelementptr %struct.__hike_compact_map, %struct.__hike_compact_map* %compact, i32 0, i32 1
  %entries = load %struct.__hike_compact_map_entry*, %struct.__hike_compact_map_entry** %p_entries
  %entry_ptr = getelementptr %struct.__hike_compact_map_entry, %struct.__hike_compact_map_entry* %entries, i64 %index
  %p_value = getelementptr %struct.__hike_compact_map_entry, %struct.__hike_compact_map_entry* %entry_ptr, i32 0, i32 2
  store i64 %value, i64* %p_value
  ret void
}

define internal i1 @__hike_cdict_get_boxed(%struct.__hike_map* %m, i64 %key, i64* %out, i8* %zero) {
entry:
  %found = call i1 @__hike_cdict_get(%struct.__hike_map* %m, i64 %key, i64* %out)
  br i1 %found, label %done, label %missing
missing:
  %z = ptrtoint i8* %zero to i64
  store i64 %z, i64* %out
  br label %done
done:
  ret i1 %found
}

define internal i1 @__hike_cdict_get_boxed_ok(%struct.__hike_map* %m, i64 %key, i64* %out, i8* %zero) {
entry:
  %found = call i1 @__hike_cdict_get_boxed(%struct.__hike_map* %m, i64 %key, i64* %out, i8* %zero)
  ret i1 %found
}

define internal i1 @__hike_cdict_get_boxed_str(%struct.__hike_map* %m, i8* %ptr, i64 %len, i64* %out, i8* %zero) {
entry:
  %found = call i1 @__hike_cdict_get_str(%struct.__hike_map* %m, i8* %ptr, i64 %len, i64* %out)
  br i1 %found, label %done, label %missing
missing:
  %z = ptrtoint i8* %zero to i64
  store i64 %z, i64* %out
  br label %done
done:
  ret i1 %found
}

define internal i1 @__hike_cdict_get_boxed_str_ok(%struct.__hike_map* %m, i8* %ptr, i64 %len, i64* %out, i8* %zero) {
entry:
  %found = call i1 @__hike_cdict_get_boxed_str(%struct.__hike_map* %m, i8* %ptr, i64 %len, i64* %out, i8* %zero)
  ret i1 %found
}

define internal void @__hike_cdict_delete(%struct.__hike_map* %m, i64 %key) {
entry:
  %compact = call %struct.__hike_compact_map* @__hike_cdict_state(%struct.__hike_map* %m)
  %ignored = call i1 @__hike_compact_map_delete(%struct.__hike_compact_map* %compact, i64 %key, i64 %key)
  ret void
}

define internal void @__hike_cdict_delete_str(%struct.__hike_map* %m, i8* %ptr, i64 %len) {
entry:
  %key = alloca %struct.__hike_string_key
  %p_ptr = getelementptr %struct.__hike_string_key, %struct.__hike_string_key* %key, i32 0, i32 0
  store i8* %ptr, i8** %p_ptr
  %p_len = getelementptr %struct.__hike_string_key, %struct.__hike_string_key* %key, i32 0, i32 1
  store i64 %len, i64* %p_len
  %token = ptrtoint %struct.__hike_string_key* %key to i64
  %hash = call i64 @__hike_hash_str(i8* %key)
  %compact = call %struct.__hike_compact_map* @__hike_cdict_state(%struct.__hike_map* %m)
  %ignored = call i1 @__hike_compact_map_delete(%struct.__hike_compact_map* %compact, i64 %token, i64 %hash)
  ret void
}

define internal void @__hike_cdict_delete_str_hash(%struct.__hike_map* %m, i8* %ptr, i64 %len, i64 %hash) {
entry:
  %key = alloca %struct.__hike_string_key
  %p_ptr = getelementptr %struct.__hike_string_key, %struct.__hike_string_key* %key, i32 0, i32 0
  store i8* %ptr, i8** %p_ptr
  %p_len = getelementptr %struct.__hike_string_key, %struct.__hike_string_key* %key, i32 0, i32 1
  store i64 %len, i64* %p_len
  %token = ptrtoint %struct.__hike_string_key* %key to i64
  %compact = call %struct.__hike_compact_map* @__hike_cdict_state(%struct.__hike_map* %m)
  %ignored = call i1 @__hike_compact_map_delete(%struct.__hike_compact_map* %compact, i64 %token, i64 %hash)
  ret void
}

define internal i64 @__hike_cdict_len(%struct.__hike_map* %m) {
entry:
  %is_null = icmp eq %struct.__hike_map* %m, null
  br i1 %is_null, label %empty, label %present
empty:
  ret i64 0
present:
  %compact = call %struct.__hike_compact_map* @__hike_cdict_state(%struct.__hike_map* %m)
  %len = call i64 @__hike_compact_map_len(%struct.__hike_compact_map* %compact)
  ret i64 %len
}

define internal i1 @__hike_cdict_entry_at(%struct.__hike_map* %m, i64 %ordinal, i64* %out_key, i64* %out_value) {
entry:
  %compact = call %struct.__hike_compact_map* @__hike_cdict_state(%struct.__hike_map* %m)
  %p_len = getelementptr %struct.__hike_compact_map, %struct.__hike_compact_map* %compact, i32 0, i32 3
  %len = load i64, i64* %p_len
  br label %entry_at_loop
entry_at_loop:
  %pos = phi i64 [ 0, %entry ], [ %next_pos, %entry_at_advance ], [ %next_pos_live, %entry_at_live_advance ]
  %rank = phi i64 [ 0, %entry ], [ %rank, %entry_at_advance ], [ %next_rank, %entry_at_live_advance ]
  %in_range = icmp ult i64 %pos, %len
  br i1 %in_range, label %entry_at_probe, label %entry_at_not_found
entry_at_probe:
  %found = call i1 @__hike_compact_map_entry_at(%struct.__hike_compact_map* %compact, i64 %pos, i64* %out_key, i64* %out_value)
  br i1 %found, label %entry_at_live, label %entry_at_advance
entry_at_live:
  %is_target = icmp eq i64 %rank, %ordinal
  br i1 %is_target, label %entry_at_done, label %entry_at_live_advance
entry_at_advance:
  %next_pos = add i64 %pos, 1
  br label %entry_at_loop
entry_at_live_advance:
  %next_pos_live = add i64 %pos, 1
  %next_rank = add i64 %rank, 1
  br label %entry_at_loop
entry_at_done:
  ret i1 true
entry_at_not_found:
  store i64 0, i64* %out_key
  store i64 0, i64* %out_value
  ret i1 false
}

; Compact Dict ABI.  indices stores entry numbers (-1 empty, -2 deleted),
; while entries remains dense and is kept in insertion order by the lowering.
define internal void @__hike_cdict_legacy_append(%struct.__hike_compact_map* %m, %struct.__hike_compact_map_entry* %new_entry) {
entry:
  %state_raw = bitcast %struct.__hike_compact_map* %m to i8*
  %legacy_raw = getelementptr i8, i8* %state_raw, i64 -32
  %legacy = bitcast i8* %legacy_raw to %struct.__hike_map*
  %p_buckets = getelementptr %struct.__hike_map, %struct.__hike_map* %legacy, i32 0, i32 0
  %buckets = load %struct.__hike_map_entry**, %struct.__hike_map_entry*** %p_buckets
  %p_head = getelementptr %struct.__hike_map_entry*, %struct.__hike_map_entry** %buckets, i64 0
  %head = load %struct.__hike_map_entry*, %struct.__hike_map_entry** %p_head
  %entry_legacy = bitcast %struct.__hike_compact_map_entry* %new_entry to %struct.__hike_map_entry*
  %p_entry_next = getelementptr %struct.__hike_map_entry, %struct.__hike_map_entry* %entry_legacy, i32 0, i32 3
  store %struct.__hike_map_entry* null, %struct.__hike_map_entry** %p_entry_next
  %has_head = icmp ne %struct.__hike_map_entry* %head, null
  br i1 %has_head, label %find_tail, label %store_head
store_head:
  store %struct.__hike_map_entry* %entry_legacy, %struct.__hike_map_entry** %p_head
  ret void
find_tail:
  br label %tail_loop
tail_loop:
  %current = phi %struct.__hike_map_entry* [ %head, %find_tail ], [ %next, %tail_next ]
  %p_current_next = getelementptr %struct.__hike_map_entry, %struct.__hike_map_entry* %current, i32 0, i32 3
  %next = load %struct.__hike_map_entry*, %struct.__hike_map_entry** %p_current_next
  %has_next = icmp ne %struct.__hike_map_entry* %next, null
  br i1 %has_next, label %tail_next, label %store_tail
tail_next:
  br label %tail_loop
store_tail:
  store %struct.__hike_map_entry* %entry_legacy, %struct.__hike_map_entry** %p_current_next
  ret void
}

define internal i1 @__hike_compact_key_eq(%struct.__hike_compact_map* %m, i64 %left, i64 %right) {
entry:
  %p_str = getelementptr %struct.__hike_compact_map, %struct.__hike_compact_map* %m, i32 0, i32 5
  %is_str = load i64, i64* %p_str
  %same_kind = icmp ne i64 %is_str, 0
  br i1 %same_kind, label %string_key, label %integer_key
integer_key:
  %same_int = icmp eq i64 %left, %right
  ret i1 %same_int
string_key:
  %left_ptr = inttoptr i64 %left to i8*
  %right_ptr = inttoptr i64 %right to i8*
  %same_string = call i1 @__hike_map_key_eq(i64 %left, i64 %right, i64 1)
  ret i1 %same_string
}

define internal %struct.__hike_compact_map* @__hike_compact_map_create(i64 %requested_cap, i64 %is_str) {
entry:
  %cap_ok = icmp uge i64 %requested_cap, 8
  %cap = select i1 %cap_ok, i64 %requested_cap, i64 8
  %map_raw = call i8* @malloc(i64 88)
  %state_raw = getelementptr i8, i8* %map_raw, i64 32
  %map = bitcast i8* %state_raw to %struct.__hike_compact_map*
  %index_bytes = mul i64 %cap, 8
  %index_raw = call i8* @malloc(i64 %index_bytes)
  %indices = bitcast i8* %index_raw to i64*
  %entry_bytes = mul i64 %cap, 40
  %entry_raw = call i8* @malloc(i64 %entry_bytes)
  %entries = bitcast i8* %entry_raw to %struct.__hike_compact_map_entry*
  br label %init
init:
  %i = phi i64 [ 0, %entry ], [ %next, %init_body ]
  %done = icmp uge i64 %i, %cap
  br i1 %done, label %store_map, label %init_body
init_body:
  %p = getelementptr i64, i64* %indices, i64 %i
  store i64 -1, i64* %p
  %next = add i64 %i, 1
  br label %init
store_map:
  %p_indices = getelementptr %struct.__hike_compact_map, %struct.__hike_compact_map* %map, i32 0, i32 0
  store i64* %indices, i64** %p_indices
  %p_entries = getelementptr %struct.__hike_compact_map, %struct.__hike_compact_map* %map, i32 0, i32 1
  store %struct.__hike_compact_map_entry* %entries, %struct.__hike_compact_map_entry** %p_entries
  %p_cap = getelementptr %struct.__hike_compact_map, %struct.__hike_compact_map* %map, i32 0, i32 2
  store i64 %cap, i64* %p_cap
  %p_len = getelementptr %struct.__hike_compact_map, %struct.__hike_compact_map* %map, i32 0, i32 3
  store i64 0, i64* %p_len
  %p_live = getelementptr %struct.__hike_compact_map, %struct.__hike_compact_map* %map, i32 0, i32 4
  store i64 0, i64* %p_live
  %p_str = getelementptr %struct.__hike_compact_map, %struct.__hike_compact_map* %map, i32 0, i32 5
  store i64 %is_str, i64* %p_str
  %p_entry_cap = getelementptr %struct.__hike_compact_map, %struct.__hike_compact_map* %map, i32 0, i32 6
  store i64 %cap, i64* %p_entry_cap
  ret %struct.__hike_compact_map* %map
}

; Clone the compact map backing a source-level map value. The public map
; pointer is the legacy-compatible address 32 bytes before the compact state.
define internal %struct.__hike_map* @__hike_mapped_compact_map_clone(%struct.__hike_map* %src) {
entry:
  %is_null = icmp eq %struct.__hike_map* %src, null
  br i1 %is_null, label %null_ret, label %load_src
null_ret:
  ret %struct.__hike_map* null
load_src:
  %src_raw = bitcast %struct.__hike_map* %src to i8*
  %src_state_raw = getelementptr i8, i8* %src_raw, i64 32
  %src_state = bitcast i8* %src_state_raw to %struct.__hike_compact_map*
  %src_cap_p = getelementptr %struct.__hike_compact_map, %struct.__hike_compact_map* %src_state, i32 0, i32 2
  %src_cap = load i64, i64* %src_cap_p
  %src_entry_cap_p = getelementptr %struct.__hike_compact_map, %struct.__hike_compact_map* %src_state, i32 0, i32 6
  %src_entry_cap = load i64, i64* %src_entry_cap_p
  %map_raw = call i8* @malloc(i64 88)
  %dst_raw = getelementptr i8, i8* %map_raw, i64 32
  %dst_state = bitcast i8* %dst_raw to %struct.__hike_compact_map*
  %state_bytes = mul i64 7, 8
  %state_copy = call i8* @memcpy(i8* %dst_raw, i8* %src_state_raw, i64 %state_bytes)
  %index_bytes = mul i64 %src_cap, 8
  %src_indices_p = getelementptr %struct.__hike_compact_map, %struct.__hike_compact_map* %src_state, i32 0, i32 0
  %src_indices = load i64*, i64** %src_indices_p
  %index_raw = call i8* @malloc(i64 %index_bytes)
  %dst_indices = bitcast i8* %index_raw to i64*
  %src_indices_bytes = bitcast i64* %src_indices to i8*
  %index_copy = call i8* @memcpy(i8* %index_raw, i8* %src_indices_bytes, i64 %index_bytes)
  %dst_indices_p = getelementptr %struct.__hike_compact_map, %struct.__hike_compact_map* %dst_state, i32 0, i32 0
  store i64* %dst_indices, i64** %dst_indices_p
  %entry_bytes = mul i64 %src_entry_cap, 40
  %src_entries_p = getelementptr %struct.__hike_compact_map, %struct.__hike_compact_map* %src_state, i32 0, i32 1
  %src_entries = load %struct.__hike_compact_map_entry*, %struct.__hike_compact_map_entry** %src_entries_p
  %entry_raw = call i8* @malloc(i64 %entry_bytes)
  %dst_entries = bitcast i8* %entry_raw to %struct.__hike_compact_map_entry*
  %src_entries_bytes = bitcast %struct.__hike_compact_map_entry* %src_entries to i8*
  %entry_copy = call i8* @memcpy(i8* %entry_raw, i8* %src_entries_bytes, i64 %entry_bytes)
  %dst_entries_p = getelementptr %struct.__hike_compact_map, %struct.__hike_compact_map* %dst_state, i32 0, i32 1
  store %struct.__hike_compact_map_entry* %dst_entries, %struct.__hike_compact_map_entry** %dst_entries_p
  %result = bitcast i8* %map_raw to %struct.__hike_map*
  ret %struct.__hike_map* %result
}

define internal i1 @__hike_compact_map_get(%struct.__hike_compact_map* %m, i64 %key, i64 %hash, i64* %out) {
entry:
  store i64 0, i64* %out
  %null_m = icmp eq %struct.__hike_compact_map* %m, null
  br i1 %null_m, label %not_found, label %load_map
load_map:
  %p_cap = getelementptr %struct.__hike_compact_map, %struct.__hike_compact_map* %m, i32 0, i32 2
  %cap = load i64, i64* %p_cap
  %p_indices = getelementptr %struct.__hike_compact_map, %struct.__hike_compact_map* %m, i32 0, i32 0
  %indices = load i64*, i64** %p_indices
  %p_entries = getelementptr %struct.__hike_compact_map, %struct.__hike_compact_map* %m, i32 0, i32 1
  %entries = load %struct.__hike_compact_map_entry*, %struct.__hike_compact_map_entry** %p_entries
  %start = urem i64 %hash, %cap
  br label %probe
probe:
  %slot = phi i64 [ %start, %load_map ], [ %next_slot, %advance ]
  %tries = phi i64 [ 0, %load_map ], [ %next_try, %advance ]
  %p_index = getelementptr i64, i64* %indices, i64 %slot
  %entry_index = load i64, i64* %p_index
  %empty = icmp eq i64 %entry_index, -1
  br i1 %empty, label %not_found, label %check_deleted
check_deleted:
  %deleted = icmp eq i64 %entry_index, -2
  br i1 %deleted, label %next, label %check_entry
check_entry:
  %entry_ptr = getelementptr %struct.__hike_compact_map_entry, %struct.__hike_compact_map_entry* %entries, i64 %entry_index
  %p_hash = getelementptr %struct.__hike_compact_map_entry, %struct.__hike_compact_map_entry* %entry_ptr, i32 0, i32 0
  %stored_hash = load i64, i64* %p_hash
  %hash_match = icmp eq i64 %stored_hash, %hash
  br i1 %hash_match, label %check_key, label %next
check_key:
  %p_key = getelementptr %struct.__hike_compact_map_entry, %struct.__hike_compact_map_entry* %entry_ptr, i32 0, i32 1
  %stored_key = load i64, i64* %p_key
  %key_match = call i1 @__hike_compact_key_eq(%struct.__hike_compact_map* %m, i64 %stored_key, i64 %key)
  br i1 %key_match, label %found, label %next
found:
  %p_value = getelementptr %struct.__hike_compact_map_entry, %struct.__hike_compact_map_entry* %entry_ptr, i32 0, i32 2
  %value = load i64, i64* %p_value
  store i64 %value, i64* %out
  ret i1 true
next:
  %next_try = add i64 %tries, 1
  %exhausted = icmp uge i64 %next_try, %cap
  br i1 %exhausted, label %not_found, label %advance
advance:
  %raw_next = add i64 %slot, 1
  %wrapped = icmp uge i64 %raw_next, %cap
  %next_slot = select i1 %wrapped, i64 0, i64 %raw_next
  br label %probe
not_found:
  ret i1 false
}

define internal void @__hike_compact_map_grow(%struct.__hike_compact_map* %m) {
entry:
  %p_cap = getelementptr %struct.__hike_compact_map, %struct.__hike_compact_map* %m, i32 0, i32 2
  %old_cap = load i64, i64* %p_cap
  %new_cap = mul i64 %old_cap, 2
  %p_indices = getelementptr %struct.__hike_compact_map, %struct.__hike_compact_map* %m, i32 0, i32 0
  %old_indices = load i64*, i64** %p_indices
  %new_index_bytes = mul i64 %new_cap, 8
  %new_index_raw = call i8* @malloc(i64 %new_index_bytes)
  %new_indices = bitcast i8* %new_index_raw to i64*
  br label %init_indices
init_indices:
  %ii = phi i64 [ 0, %entry ], [ %ii_next, %init_body ]
  %ii_done = icmp uge i64 %ii, %new_cap
  br i1 %ii_done, label %copy_entries, label %init_body
init_body:
  %ip = getelementptr i64, i64* %new_indices, i64 %ii
  store i64 -1, i64* %ip
  %ii_next = add i64 %ii, 1
  br label %init_indices
copy_entries:
  %p_entries = getelementptr %struct.__hike_compact_map, %struct.__hike_compact_map* %m, i32 0, i32 1
  %old_entries = load %struct.__hike_compact_map_entry*, %struct.__hike_compact_map_entry** %p_entries
  %old_entry_bytes = mul i64 %old_cap, 40
  %new_entry_bytes = mul i64 %new_cap, 40
  %new_entry_raw = call i8* @malloc(i64 %new_entry_bytes)
  %new_entries = bitcast i8* %new_entry_raw to %struct.__hike_compact_map_entry*
  %old_entries_raw = bitcast %struct.__hike_compact_map_entry* %old_entries to i8*
  call i8* @memcpy(i8* %new_entry_raw, i8* %old_entries_raw, i64 %old_entry_bytes)
  %p_len = getelementptr %struct.__hike_compact_map, %struct.__hike_compact_map* %m, i32 0, i32 3
  %entry_len = load i64, i64* %p_len
  br label %rehash
rehash:
  %ri = phi i64 [ 0, %copy_entries ], [ %ri_next, %rehash_next ]
  %ri_done = icmp uge i64 %ri, %entry_len
  br i1 %ri_done, label %finish, label %rehash_body
rehash_body:
  %old_ep = getelementptr %struct.__hike_compact_map_entry, %struct.__hike_compact_map_entry* %new_entries, i64 %ri
  %state_p = getelementptr %struct.__hike_compact_map_entry, %struct.__hike_compact_map_entry* %old_ep, i32 0, i32 4
  %state = load i64, i64* %state_p
  %live = icmp ne i64 %state, 0
  br i1 %live, label %rehash_live, label %rehash_next
rehash_live:
  %hash_p = getelementptr %struct.__hike_compact_map_entry, %struct.__hike_compact_map_entry* %old_ep, i32 0, i32 0
  %hash = load i64, i64* %hash_p
  %slot = urem i64 %hash, %new_cap
  br label %find_slot
find_slot:
  %fs = phi i64 [ %slot, %rehash_live ], [ %fs_next, %find_next ]
  %fsp = getelementptr i64, i64* %new_indices, i64 %fs
  %fsv = load i64, i64* %fsp
  %free_slot = icmp eq i64 %fsv, -1
  br i1 %free_slot, label %store_slot, label %find_next
find_next:
  %fs_raw = add i64 %fs, 1
  %fs_wrap = icmp uge i64 %fs_raw, %new_cap
  %fs_next = select i1 %fs_wrap, i64 0, i64 %fs_raw
  br label %find_slot
store_slot:
  store i64 %ri, i64* %fsp
  br label %rehash_next
rehash_next:
  %ri_next = add i64 %ri, 1
  br label %rehash
finish:
  %old_indices_raw = bitcast i64* %old_indices to i8*
  call void @free(i8* %old_indices_raw)
  call void @free(i8* %old_entries_raw)
  store i64* %new_indices, i64** %p_indices
  store %struct.__hike_compact_map_entry* %new_entries, %struct.__hike_compact_map_entry** %p_entries
  store i64 %new_cap, i64* %p_cap
  %p_entry_cap = getelementptr %struct.__hike_compact_map, %struct.__hike_compact_map* %m, i32 0, i32 6
  store i64 %new_cap, i64* %p_entry_cap
  ret void
}

define internal void @__hike_compact_map_set(%struct.__hike_compact_map* %m, i64 %key, i64 %hash, i64 %value) {
entry:
  %null_m = icmp eq %struct.__hike_compact_map* %m, null
  br i1 %null_m, label %done, label %load_map
load_map:
  %p_cap = getelementptr %struct.__hike_compact_map, %struct.__hike_compact_map* %m, i32 0, i32 2
  %cap = load i64, i64* %p_cap
  %p_indices = getelementptr %struct.__hike_compact_map, %struct.__hike_compact_map* %m, i32 0, i32 0
  %indices = load i64*, i64** %p_indices
  %p_entries = getelementptr %struct.__hike_compact_map, %struct.__hike_compact_map* %m, i32 0, i32 1
  %entries = load %struct.__hike_compact_map_entry*, %struct.__hike_compact_map_entry** %p_entries
  %p_len = getelementptr %struct.__hike_compact_map, %struct.__hike_compact_map* %m, i32 0, i32 3
  %entry_len = load i64, i64* %p_len
  %p_live = getelementptr %struct.__hike_compact_map, %struct.__hike_compact_map* %m, i32 0, i32 4
  %live = load i64, i64* %p_live
  %live4 = mul i64 %live, 4
  %cap3 = mul i64 %cap, 3
  %needs_load_grow = icmp uge i64 %live4, %cap3
  %p_entry_cap_check = getelementptr %struct.__hike_compact_map, %struct.__hike_compact_map* %m, i32 0, i32 6
  %entry_cap_check = load i64, i64* %p_entry_cap_check
  %entry_full = icmp uge i64 %entry_len, %entry_cap_check
  %needs_grow = or i1 %needs_load_grow, %entry_full
  br i1 %needs_grow, label %grow, label %begin_probe
grow:
  call void @__hike_compact_map_grow(%struct.__hike_compact_map* %m)
  br label %load_map
begin_probe:
  %start = urem i64 %hash, %cap
  br label %probe
probe:
  %slot = phi i64 [ %start, %begin_probe ], [ %next_slot, %advance ]
  %tries = phi i64 [ 0, %begin_probe ], [ %next_try, %advance ]
  %p_index = getelementptr i64, i64* %indices, i64 %slot
  %entry_index = load i64, i64* %p_index
  %empty = icmp eq i64 %entry_index, -1
  %deleted = icmp eq i64 %entry_index, -2
  br i1 %empty, label %insert, label %check_deleted
check_deleted:
  br i1 %deleted, label %insert, label %check_entry
check_entry:
  %entry_ptr = getelementptr %struct.__hike_compact_map_entry, %struct.__hike_compact_map_entry* %entries, i64 %entry_index
  %p_hash = getelementptr %struct.__hike_compact_map_entry, %struct.__hike_compact_map_entry* %entry_ptr, i32 0, i32 0
  %stored_hash = load i64, i64* %p_hash
  %hash_match = icmp eq i64 %stored_hash, %hash
  br i1 %hash_match, label %check_key, label %next
check_key:
  %p_key = getelementptr %struct.__hike_compact_map_entry, %struct.__hike_compact_map_entry* %entry_ptr, i32 0, i32 1
  %stored_key = load i64, i64* %p_key
  %key_match = call i1 @__hike_compact_key_eq(%struct.__hike_compact_map* %m, i64 %stored_key, i64 %key)
  br i1 %key_match, label %update, label %next
update:
  %p_value = getelementptr %struct.__hike_compact_map_entry, %struct.__hike_compact_map_entry* %entry_ptr, i32 0, i32 2
  store i64 %value, i64* %p_value
  br label %done
insert:
  %entry_ptr_new = getelementptr %struct.__hike_compact_map_entry, %struct.__hike_compact_map_entry* %entries, i64 %entry_len
  %p_hash_new = getelementptr %struct.__hike_compact_map_entry, %struct.__hike_compact_map_entry* %entry_ptr_new, i32 0, i32 0
  store i64 %hash, i64* %p_hash_new
  %p_key_new = getelementptr %struct.__hike_compact_map_entry, %struct.__hike_compact_map_entry* %entry_ptr_new, i32 0, i32 1
  store i64 %key, i64* %p_key_new
  %p_value_new = getelementptr %struct.__hike_compact_map_entry, %struct.__hike_compact_map_entry* %entry_ptr_new, i32 0, i32 2
  store i64 %value, i64* %p_value_new
  %p_state_new = getelementptr %struct.__hike_compact_map_entry, %struct.__hike_compact_map_entry* %entry_ptr_new, i32 0, i32 4
  store i64 1, i64* %p_state_new
  %state_raw_new = bitcast %struct.__hike_compact_map* %m to i8*
  store i64 %entry_len, i64* %p_index
  %next_len = add i64 %entry_len, 1
  store i64 %next_len, i64* %p_len
  %p_live2 = getelementptr %struct.__hike_compact_map, %struct.__hike_compact_map* %m, i32 0, i32 4
  %live2 = load i64, i64* %p_live2
  %next_live2 = add i64 %live2, 1
  store i64 %next_live2, i64* %p_live2
  br label %done
next:
  %next_try = add i64 %tries, 1
  %exhausted = icmp uge i64 %next_try, %cap
  br i1 %exhausted, label %done, label %advance
advance:
  %raw_next = add i64 %slot, 1
  %wrapped = icmp uge i64 %raw_next, %cap
  %next_slot = select i1 %wrapped, i64 0, i64 %raw_next
  br label %probe
done:
  ret void
}

define internal i1 @__hike_compact_map_delete(%struct.__hike_compact_map* %m, i64 %key, i64 %hash) {
entry:
  %null_m = icmp eq %struct.__hike_compact_map* %m, null
  br i1 %null_m, label %not_found, label %load_map
load_map:
  %p_cap = getelementptr %struct.__hike_compact_map, %struct.__hike_compact_map* %m, i32 0, i32 2
  %cap = load i64, i64* %p_cap
  %p_indices = getelementptr %struct.__hike_compact_map, %struct.__hike_compact_map* %m, i32 0, i32 0
  %indices = load i64*, i64** %p_indices
  %p_entries = getelementptr %struct.__hike_compact_map, %struct.__hike_compact_map* %m, i32 0, i32 1
  %entries = load %struct.__hike_compact_map_entry*, %struct.__hike_compact_map_entry** %p_entries
  %start = urem i64 %hash, %cap
  br label %probe
probe:
  %slot = phi i64 [ %start, %load_map ], [ %next_slot, %advance ]
  %tries = phi i64 [ 0, %load_map ], [ %next_try, %advance ]
  %p_index = getelementptr i64, i64* %indices, i64 %slot
  %entry_index = load i64, i64* %p_index
  %empty = icmp eq i64 %entry_index, -1
  br i1 %empty, label %not_found, label %check_deleted
check_deleted:
  %deleted = icmp eq i64 %entry_index, -2
  br i1 %deleted, label %next, label %check_entry
check_entry:
  %entry_ptr = getelementptr %struct.__hike_compact_map_entry, %struct.__hike_compact_map_entry* %entries, i64 %entry_index
  %p_hash = getelementptr %struct.__hike_compact_map_entry, %struct.__hike_compact_map_entry* %entry_ptr, i32 0, i32 0
  %stored_hash = load i64, i64* %p_hash
  %hash_match = icmp eq i64 %stored_hash, %hash
  br i1 %hash_match, label %check_key, label %next
check_key:
  %p_key = getelementptr %struct.__hike_compact_map_entry, %struct.__hike_compact_map_entry* %entry_ptr, i32 0, i32 1
  %stored_key = load i64, i64* %p_key
  %key_match = call i1 @__hike_compact_key_eq(%struct.__hike_compact_map* %m, i64 %stored_key, i64 %key)
  br i1 %key_match, label %remove, label %next
remove:
  store i64 -2, i64* %p_index
  %p_state = getelementptr %struct.__hike_compact_map_entry, %struct.__hike_compact_map_entry* %entry_ptr, i32 0, i32 4
  store i64 0, i64* %p_state
  %p_live = getelementptr %struct.__hike_compact_map, %struct.__hike_compact_map* %m, i32 0, i32 4
  %live = load i64, i64* %p_live
  %new_live = sub i64 %live, 1
  store i64 %new_live, i64* %p_live
  ret i1 true
next:
  %next_try = add i64 %tries, 1
  %exhausted = icmp uge i64 %next_try, %cap
  br i1 %exhausted, label %not_found, label %advance
advance:
  %raw_next = add i64 %slot, 1
  %wrapped = icmp uge i64 %raw_next, %cap
  %next_slot = select i1 %wrapped, i64 0, i64 %raw_next
  br label %probe
not_found:
  ret i1 false
}

define internal i64 @__hike_compact_map_len(%struct.__hike_compact_map* %m) {
entry:
  %null_m = icmp eq %struct.__hike_compact_map* %m, null
  br i1 %null_m, label %zero, label %load_live
load_live:
  %p_live = getelementptr %struct.__hike_compact_map, %struct.__hike_compact_map* %m, i32 0, i32 4
  %live = load i64, i64* %p_live
  ret i64 %live
zero:
  ret i64 0
}

define internal i1 @__hike_compact_map_entry_at(%struct.__hike_compact_map* %m, i64 %ordinal, i64* %out_key, i64* %out_value) {
entry:
  %null_m = icmp eq %struct.__hike_compact_map* %m, null
  br i1 %null_m, label %not_found, label %load_entries
load_entries:
  %p_len = getelementptr %struct.__hike_compact_map, %struct.__hike_compact_map* %m, i32 0, i32 3
  %len = load i64, i64* %p_len
  %out_of_range = icmp uge i64 %ordinal, %len
  br i1 %out_of_range, label %not_found, label %scan
scan:
  %p_entries = getelementptr %struct.__hike_compact_map, %struct.__hike_compact_map* %m, i32 0, i32 1
  %entries = load %struct.__hike_compact_map_entry*, %struct.__hike_compact_map_entry** %p_entries
  %entry_ptr = getelementptr %struct.__hike_compact_map_entry, %struct.__hike_compact_map_entry* %entries, i64 %ordinal
  %p_state = getelementptr %struct.__hike_compact_map_entry, %struct.__hike_compact_map_entry* %entry_ptr, i32 0, i32 4
  %state = load i64, i64* %p_state
  %live = icmp ne i64 %state, 0
  br i1 %live, label %copy, label %not_found
copy:
  %p_key = getelementptr %struct.__hike_compact_map_entry, %struct.__hike_compact_map_entry* %entry_ptr, i32 0, i32 1
  %key = load i64, i64* %p_key
  %p_value = getelementptr %struct.__hike_compact_map_entry, %struct.__hike_compact_map_entry* %entry_ptr, i32 0, i32 2
  %value = load i64, i64* %p_value
  store i64 %key, i64* %out_key
  store i64 %value, i64* %out_value
  ret i1 true
not_found:
  store i64 0, i64* %out_key
  store i64 0, i64* %out_value
  ret i1 false
}

define internal i32 @__hike_utf8_rune_size(i8* %ptr, i64 %len) #0 {
entry:
  %empty = icmp eq i64 %len, 0
  br i1 %empty, label %zero, label %read
zero:
  ret i32 0
read:
  %p = load i8, i8* %ptr
  %b = zext i8 %p to i32
  %ascii = icmp ult i32 %b, 128
  br i1 %ascii, label %one, label %check2
check2:
  %b_lt224 = icmp ult i32 %b, 224
  %len_ge2 = icmp uge i64 %len, 2
  %two_ok = and i1 %b_lt224, %len_ge2
  br i1 %two_ok, label %two, label %check3
check3:
  %b_lt240 = icmp ult i32 %b, 240
  %len_ge3 = icmp uge i64 %len, 3
  %three_ok = and i1 %b_lt240, %len_ge3
  br i1 %three_ok, label %three, label %check4
check4:
  %four_ok = icmp uge i64 %len, 4
  br i1 %four_ok, label %four, label %one
one: ret i32 1
two: ret i32 2
three: ret i32 3
four: ret i32 4
}

define internal i32 @__hike_utf8_decode_rune(i8* %ptr, i64 %len) #0 {
entry:
  %n = call i32 @__hike_utf8_rune_size(i8* %ptr, i64 %len)
  %p0 = load i8, i8* %ptr
  %b0 = zext i8 %p0 to i32
  %is_ascii = icmp eq i32 %n, 1
  br i1 %is_ascii, label %ascii, label %multi
ascii:
  %ascii_ok = icmp ult i32 %b0, 128
  %ascii_r = select i1 %ascii_ok, i32 %b0, i32 65533
  ret i32 %ascii_r
multi:
  %p1p = getelementptr i8, i8* %ptr, i64 1
  %p1 = load i8, i8* %p1p
  %b1 = zext i8 %p1 to i32
  %c1 = and i32 %b1, 63
  %is2 = icmp eq i32 %n, 2
  br i1 %is2, label %two, label %three_or_four
two:
  %x2a = and i32 %b0, 31
  %x2b = shl i32 %x2a, 6
  %x2 = or i32 %x2b, %c1
  ret i32 %x2
three_or_four:
  %p2p = getelementptr i8, i8* %ptr, i64 2
  %p2 = load i8, i8* %p2p
  %b2 = zext i8 %p2 to i32
  %c2 = and i32 %b2, 63
  %is3 = icmp eq i32 %n, 3
  br i1 %is3, label %three, label %four
three:
  %x3a0 = and i32 %b0, 15
  %x3a = shl i32 %x3a0, 12
  %x3b = shl i32 %c1, 6
  %x3ab = or i32 %x3a, %x3b
  %x3 = or i32 %x3ab, %c2
  ret i32 %x3
four:
  %p3p = getelementptr i8, i8* %ptr, i64 3
  %p3 = load i8, i8* %p3p
  %b3 = zext i8 %p3 to i32
  %c3 = and i32 %b3, 63
  %x4a0 = and i32 %b0, 7
  %x4a = shl i32 %x4a0, 18
  %x4b = shl i32 %c1, 12
  %x4c = shl i32 %c2, 6
  %x4ab = or i32 %x4a, %x4b
  %x4abc = or i32 %x4ab, %x4c
  %x4 = or i32 %x4abc, %c3
  ret i32 %x4
}

define internal { i8*, i32, i32 } @__hike_utf8_rune_to_string(i32 %r) #0 {
entry:
  %bad_low = icmp slt i32 %r, 0
  %bad_high = icmp ugt i32 %r, 1114111
  %bad = or i1 %bad_low, %bad_high
  %safe = select i1 %bad, i32 65533, i32 %r
  %sur_low = icmp uge i32 %safe, 55296
  %sur_high = icmp ule i32 %safe, 57343
  %sur = and i1 %sur_low, %sur_high
  %r2 = select i1 %sur, i32 65533, i32 %safe
  %lt1 = icmp ult i32 %r2, 128
  %lt2 = icmp ult i32 %r2, 2048
  %lt3 = icmp ult i32 %r2, 65536
  %n1 = select i1 %lt1, i32 1, i32 0
  %n2 = select i1 %lt2, i32 2, i32 0
  %n3 = select i1 %lt3, i32 3, i32 4
  %n12 = select i1 %lt1, i32 %n1, i32 %n2
  %n = select i1 %lt2, i32 %n12, i32 %n3
  %n64 = zext i32 %n to i64
  %size = add i64 %n64, 9
  %raw = call i8* @malloc(i64 %size)
  %cap = bitcast i8* %raw to i32*
  store i32 %n, i32* %cap
  %refp = getelementptr i8, i8* %raw, i64 4
  %ref = bitcast i8* %refp to i32*
  store i32 1, i32* %ref
  %buf = getelementptr i8, i8* %raw, i64 8
  %e1 = trunc i32 %r2 to i8
  %r6 = lshr i32 %r2, 6
  %e2a0 = or i32 192, %r6
  %e2 = trunc i32 %e2a0 to i8
  %e2b0 = and i32 %r2, 63
  %e2b1 = or i32 128, %e2b0
  %e2b = trunc i32 %e2b1 to i8
  %r12 = lshr i32 %r2, 12
  %e3a0 = or i32 224, %r12
  %e3a = trunc i32 %e3a0 to i8
  %e3b0 = and i32 %r6, 63
  %e3b1 = or i32 128, %e3b0
  %e3b = trunc i32 %e3b1 to i8
  %e3c1 = or i32 128, %e2b0
  %e3c = trunc i32 %e3c1 to i8
  %r18 = lshr i32 %r2, 18
  %e4a0 = or i32 240, %r18
  %e4a = trunc i32 %e4a0 to i8
  %e4b0 = and i32 %r12, 63
  %e4b1 = or i32 128, %e4b0
  %e4b = trunc i32 %e4b1 to i8
  %e4c0 = and i32 %r6, 63
  %e4c1 = or i32 128, %e4c0
  %e4c = trunc i32 %e4c1 to i8
  %e4d1 = or i32 128, %e2b0
  %e4d = trunc i32 %e4d1 to i8
  %first34 = select i1 %lt3, i8 %e3a, i8 %e4a
  %first24 = select i1 %lt2, i8 %e2, i8 %first34
  %first = select i1 %lt1, i8 %e1, i8 %first24
  store i8 %first, i8* %buf
  %pout1 = getelementptr i8, i8* %buf, i64 1
  %second34 = select i1 %lt3, i8 %e3b, i8 %e4b
  %second = select i1 %lt2, i8 %e2b, i8 %second34
  store i8 %second, i8* %pout1
  %pout2 = getelementptr i8, i8* %buf, i64 2
  %third = select i1 %lt3, i8 %e3c, i8 %e4c
  store i8 %third, i8* %pout2
  %pout3 = getelementptr i8, i8* %buf, i64 3
  store i8 %e4d, i8* %pout3
  %out = insertvalue { i8*, i32, i32 } { i8* null, i32 0, i32 0 }, i8* %buf, 0
  %out2 = insertvalue { i8*, i32, i32 } %out, i32 0, 1
  %out3 = insertvalue { i8*, i32, i32 } %out2, i32 %n, 2
  ret { i8*, i32, i32 } %out3
}

attributes #0 = { noinline nounwind "no-builtins" }

; Hike native Windows OS runtime (64-bit, pointer=i8*)

declare i32 @QueueUserWorkItem(i32 (i8*)*, i8*, i32)
declare i8* @CreateEventA(i8*, i32, i32, i8*)
declare i32 @SetEvent(i8*)
declare i32 @WaitForSingleObject(i8*, i32)
declare i32 @CloseHandle(i8*)
declare void @Sleep(i32)
declare i64 @GetTickCount64()
declare i8* @GetStdHandle(i32)
declare i32 @WriteFile(i8*, i8*, i32, i32*, i8*)

define void @__hike_stderr_write(i8* %data, i32 %length) {
entry:
  %handle = call i8* @GetStdHandle(i32 -12)
  %written = alloca i32, align 4
  call i32 @WriteFile(i8* %handle, i8* %data, i32 %length, i32* %written, i8* null)
  ret void
}

define internal i32 @hike_thread_spawn(i32 (i8*)* %fn, i8* %param) {
entry:
  %r = call i32 @QueueUserWorkItem(i32 (i8*)* %fn, i8* %param, i32 0)
  ret i32 %r
}
define internal i8* @hike_event_create() {
entry:
  %r = call i8* @CreateEventA(i8* null, i32 0, i32 0, i8* null)
  ret i8* %r
}
define internal i32 @hike_event_signal(i8* %ev) {
entry:
  %r = call i32 @SetEvent(i8* %ev)
  ret i32 %r
}
define internal i32 @hike_event_wait(i8* %ev, i32 %timeout) {
entry:
  %r = call i32 @WaitForSingleObject(i8* %ev, i32 %timeout)
  ret i32 %r
}
define internal i32 @hike_event_destroy(i8* %ev) {
entry:
  %r = call i32 @CloseHandle(i8* %ev)
  ret i32 %r
}
define internal void @hike_sleep_ms(i32 %ms) {
entry:
  call void @Sleep(i32 %ms)
  ret void
}
define internal i64 @hike_now_ns() {
entry:
  %ms = call i64 @GetTickCount64()
  %ns = mul i64 %ms, 1000000
  ret i64 %ns
}



declare i64 @SDL_abs(i64)
declare double @SDL_acos(double)
declare float @SDL_acosf(float)
declare i8* @SDL_AcquireCameraFrame(i8*, i8*)
declare i8* @SDL_AcquireGPUCommandBuffer(i8*)
declare i1 @SDL_AcquireGPUSwapchainTexture(i8*, i8*, i8*, i8*, i8*)
declare i64 @SDL_AddAtomicInt(i8*, i64)
declare i32 @SDL_AddAtomicU32(i8*, i64)
declare i1 @SDL_AddEventWatch(i64, i8*)
declare i64 @SDL_AddGamepadMapping(i8*)
declare i64 @SDL_AddGamepadMappingsFromFile(i8*)
declare i64 @SDL_AddGamepadMappingsFromIO(i8*, i1)
declare i1 @SDL_AddHintCallback(i8*, i64, i8*)
declare i1 @SDL_AddSurfaceAlternateImage(i8*, i8*)
declare i64 @SDL_AddTimer(i32, i64, i8*)
declare i64 @SDL_AddTimerNS(i64, i64, i8*)
declare i1 @SDL_AddVulkanRenderSemaphores(i8*, i32, i64, i64)
declare i8* @SDL_aligned_alloc_zero(i64, i64)
declare i8* @SDL_aligned_alloc(i64, i64)
declare void @SDL_aligned_free(i8*)
declare double @SDL_asin(double)
declare float @SDL_asinf(float)
declare i64 @SDL_asprintf(i8*, i8*, i64, i64)
declare i8* @SDL_AsyncIOFromFile(i8*, i8*)
declare double @SDL_atan(double)
declare double @SDL_atan2(double, double)
declare float @SDL_atan2f(float, float)
declare float @SDL_atanf(float)
declare double @SDL_atof(i8*)
declare i64 @SDL_atoi(i8*)
declare i64 @SDL_AttachVirtualJoystick(i8*)
declare i1 @SDL_AudioDevicePaused(i64)
declare i1 @SDL_AudioStreamDevicePaused(i8*)
declare i8* @SDL_BeginGPUComputePass(i8*, i8*, i32, i8*, i32)
declare i8* @SDL_BeginGPUCopyPass(i8*)
declare i8* @SDL_BeginGPURenderPass(i8*, i8*, i32, i8*)
declare i1 @SDL_BindAudioStream(i64, i8*)
declare i1 @SDL_BindAudioStreams(i64, i8*, i64)
declare void @SDL_BindGPUComputePipeline(i8*, i8*)
declare void @SDL_BindGPUComputeSamplers(i8*, i32, i8*, i32)
declare void @SDL_BindGPUComputeStorageBuffers(i8*, i32, i8*, i32)
declare void @SDL_BindGPUComputeStorageTextures(i8*, i32, i8*, i32)
declare void @SDL_BindGPUFragmentSamplers(i8*, i32, i8*, i32)
declare void @SDL_BindGPUFragmentStorageBuffers(i8*, i32, i8*, i32)
declare void @SDL_BindGPUFragmentStorageTextures(i8*, i32, i8*, i32)
declare void @SDL_BindGPUGraphicsPipeline(i8*, i8*)
declare void @SDL_BindGPUIndexBuffer(i8*, i8*, i64)
declare void @SDL_BindGPUVertexBuffers(i8*, i32, i8*, i32)
declare void @SDL_BindGPUVertexSamplers(i8*, i32, i8*, i32)
declare void @SDL_BindGPUVertexStorageBuffers(i8*, i32, i8*, i32)
declare void @SDL_BindGPUVertexStorageTextures(i8*, i32, i8*, i32)
declare void @SDL_BlitGPUTexture(i8*, i8*)
declare i1 @SDL_BlitSurface(i8*, i8*, i8*, i8*)
declare i1 @SDL_BlitSurface9Grid(i8*, i8*, i64, i64, i64, i64, float, i64, i8*, i8*)
declare i1 @SDL_BlitSurfaceScaled(i8*, i8*, i8*, i8*, i64)
declare i1 @SDL_BlitSurfaceTiled(i8*, i8*, i8*, i8*)
declare i1 @SDL_BlitSurfaceTiledWithScale(i8*, i8*, float, i64, i8*, i8*)
declare i1 @SDL_BlitSurfaceUnchecked(i8*, i8*, i8*, i8*)
declare i1 @SDL_BlitSurfaceUncheckedScaled(i8*, i8*, i8*, i8*, i64)
declare void @SDL_BroadcastCondition(i8*)
declare i8* @SDL_bsearch_r(i8*, i8*, i64, i64, i64, i8*)
declare i8* @SDL_bsearch(i8*, i8*, i64, i64, i64)
declare i32 @SDL_CalculateGPUTextureFormatSize(i64, i32, i32, i32)
declare i8* @SDL_calloc(i64, i64)
declare i1 @SDL_CancelGPUCommandBuffer(i8*)
declare i1 @SDL_CaptureMouse(i1)
declare double @SDL_ceil(double)
declare float @SDL_ceilf(float)
declare i1 @SDL_ClaimWindowForGPUDevice(i8*, i8*)
declare void @SDL_CleanupTLS()
declare i1 @SDL_ClearAudioStream(i8*)
declare i1 @SDL_ClearClipboardData()
declare i1 @SDL_ClearComposition(i8*)
declare i1 @SDL_ClearError()
declare i1 @SDL_ClearProperty(i64, i8*)
declare i1 @SDL_ClearSurface(i8*, float, float, float, float)
declare void @SDL_ClickTrayEntry(i8*)
declare i1 @SDL_CloseAsyncIO(i8*, i1, i8*, i8*)
declare void @SDL_CloseAudioDevice(i64)
declare void @SDL_CloseCamera(i8*)
declare void @SDL_CloseGamepad(i8*)
declare void @SDL_CloseHaptic(i8*)
declare i1 @SDL_CloseIO(i8*)
declare void @SDL_CloseJoystick(i8*)
declare void @SDL_CloseSensor(i8*)
declare i1 @SDL_CloseStorage(i8*)
declare i1 @SDL_CompareAndSwapAtomicInt(i8*, i64, i64)
declare i1 @SDL_CompareAndSwapAtomicPointer(i8*, i8*, i8*)
declare i1 @SDL_CompareAndSwapAtomicU32(i8*, i32, i32)
declare i64 @SDL_ComposeCustomBlendMode(i64, i64, i64, i64, i64, i64)
declare i1 @SDL_ConvertAudioSamples(i8*, i8*, i64, i8*, i8*, i8*)
declare i1 @SDL_ConvertEventToRenderCoordinates(i8*, i8*)
declare i1 @SDL_ConvertPixels(i64, i64, i64, i8*, i64, i64, i8*, i64)
declare i1 @SDL_ConvertPixelsAndColorspace(i64, i64, i64, i64, i64, i8*, i64, i64, i64, i64, i8*, i64)
declare i8* @SDL_ConvertSurface(i8*, i64)
declare i8* @SDL_ConvertSurfaceAndColorspace(i8*, i64, i8*, i64, i64)
declare i1 @SDL_CopyFile(i8*, i8*)
declare void @SDL_CopyGPUBufferToBuffer(i8*, i8*, i8*, i32, i1)
declare void @SDL_CopyGPUTextureToTexture(i8*, i8*, i8*, i32, i32, i32, i1)
declare i1 @SDL_CopyProperties(i64, i64)
declare double @SDL_copysign(double, double)
declare float @SDL_copysignf(float, float)
declare i1 @SDL_CopyStorageFile(i8*, i8*, i8*)
declare double @SDL_cos(double)
declare float @SDL_cosf(float)
declare i16 @SDL_crc16(i16, i8*, i64)
declare i32 @SDL_crc32(i32, i8*, i64)
declare i8* @SDL_CreateAnimatedCursor(i8*, i64, i64, i64)
declare i8* @SDL_CreateAsyncIOQueue()
declare i8* @SDL_CreateAudioStream(i8*, i8*)
declare i8* @SDL_CreateColorCursor(i8*, i64, i64)
declare i8* @SDL_CreateCondition()
declare i8* @SDL_CreateCursor(i8*, i8*, i64, i64, i64, i64)
declare i1 @SDL_CreateDirectory(i8*)
declare i8* @SDL_CreateEnvironment(i1)
declare i8* @SDL_CreateGPUBuffer(i8*, i8*)
declare i8* @SDL_CreateGPUComputePipeline(i8*, i8*)
declare i8* @SDL_CreateGPUDevice(i64, i1, i8*)
declare i8* @SDL_CreateGPUDeviceWithProperties(i64)
declare i8* @SDL_CreateGPUGraphicsPipeline(i8*, i8*)
declare i8* @SDL_CreateGPURenderer(i8*, i8*)
declare i8* @SDL_CreateGPURenderState(i8*, i8*)
declare i8* @SDL_CreateGPUSampler(i8*, i8*)
declare i8* @SDL_CreateGPUShader(i8*, i8*)
declare i8* @SDL_CreateGPUTexture(i8*, i8*)
declare i8* @SDL_CreateGPUTransferBuffer(i8*, i8*)
declare i64 @SDL_CreateHapticEffect(i8*, i8*)
declare i8* @SDL_CreateMutex()
declare i8* @SDL_CreatePalette(i64)
declare i8* @SDL_CreatePopupWindow(i8*, i64, i64, i64, i64, i64)
declare i8* @SDL_CreateProcess(i8*, i1)
declare i8* @SDL_CreateProcessWithProperties(i64)
declare i64 @SDL_CreateProperties()
declare i8* @SDL_CreateRenderer(i8*, i8*)
declare i8* @SDL_CreateRendererWithProperties(i64)
declare i8* @SDL_CreateRWLock()
declare i8* @SDL_CreateSemaphore(i32)
declare i8* @SDL_CreateSoftwareRenderer(i8*)
declare i1 @SDL_CreateStorageDirectory(i8*, i8*)
declare i8* @SDL_CreateSurface(i64, i64, i64)
declare i8* @SDL_CreateSurfaceFrom(i64, i64, i64, i8*, i64)
declare i8* @SDL_CreateSurfacePalette(i8*)
declare i8* @SDL_CreateSystemCursor(i64)
declare i8* @SDL_CreateTexture(i8*, i64, i64, i64, i64)
declare i8* @SDL_CreateTextureFromSurface(i8*, i8*)
declare i8* @SDL_CreateTextureWithProperties(i8*, i64)
declare i8* @SDL_CreateThreadRuntime(i64, i8*, i8*, i64, i64)
declare i8* @SDL_CreateThreadWithPropertiesRuntime(i64, i64, i64)
declare i8* @SDL_CreateTray(i8*, i8*)
declare i8* @SDL_CreateTrayMenu(i8*)
declare i8* @SDL_CreateTraySubmenu(i8*)
declare i8* @SDL_CreateTrayWithProperties(i64)
declare i8* @SDL_CreateWindow(i8*, i64, i64, i64)
declare i1 @SDL_CreateWindowAndRenderer(i8*, i64, i64, i64, i8*, i8*)
declare i8* @SDL_CreateWindowWithProperties(i64)
declare i1 @SDL_CursorVisible()
declare i1 @SDL_DateTimeToTime(i8*, i8*)
declare void @SDL_Delay(i32)
declare void @SDL_DelayNS(i64)
declare void @SDL_DelayPrecise(i64)
declare void @SDL_DestroyAsyncIOQueue(i8*)
declare void @SDL_DestroyAudioStream(i8*)
declare void @SDL_DestroyCondition(i8*)
declare void @SDL_DestroyCursor(i8*)
declare void @SDL_DestroyEnvironment(i8*)
declare void @SDL_DestroyGPUDevice(i8*)
declare void @SDL_DestroyGPURenderState(i8*)
declare void @SDL_DestroyHapticEffect(i8*, i64)
declare void @SDL_DestroyMutex(i8*)
declare void @SDL_DestroyPalette(i8*)
declare void @SDL_DestroyProcess(i8*)
declare void @SDL_DestroyProperties(i64)
declare void @SDL_DestroyRenderer(i8*)
declare void @SDL_DestroyRWLock(i8*)
declare void @SDL_DestroySemaphore(i8*)
declare void @SDL_DestroySurface(i8*)
declare void @SDL_DestroyTexture(i8*)
declare void @SDL_DestroyTray(i8*)
declare void @SDL_DestroyWindow(i8*)
declare i1 @SDL_DestroyWindowSurface(i8*)
declare void @SDL_DetachThread(i8*)
declare i1 @SDL_DetachVirtualJoystick(i64)
declare i1 @SDL_DisableScreenSaver()
declare void @SDL_DispatchGPUCompute(i8*, i32, i32, i32)
declare void @SDL_DispatchGPUComputeIndirect(i8*, i8*, i32)
declare void @SDL_DownloadFromGPUBuffer(i8*, i8*, i8*)
declare void @SDL_DownloadFromGPUTexture(i8*, i8*, i8*)
declare void @SDL_DrawGPUIndexedPrimitives(i8*, i32, i32, i32, i32, i32)
declare void @SDL_DrawGPUIndexedPrimitivesIndirect(i8*, i8*, i32, i32)
declare void @SDL_DrawGPUPrimitives(i8*, i32, i32, i32, i32)
declare void @SDL_DrawGPUPrimitivesIndirect(i8*, i8*, i32, i32)
declare i8* @SDL_DuplicateSurface(i8*)
declare i64 @SDL_EGL_GetCurrentConfig()
declare i64 @SDL_EGL_GetCurrentDisplay()
declare i64 @SDL_EGL_GetProcAddress(i8*)
declare i64 @SDL_EGL_GetWindowSurface(i8*)
declare void @SDL_EGL_SetAttributeCallbacks(i64, i64, i64, i8*)
declare i1 @SDL_EnableScreenSaver()
declare i8* @SDL_EncodeURL(i8*, i8*)
declare void @SDL_EndGPUComputePass(i8*)
declare void @SDL_EndGPUCopyPass(i8*)
declare void @SDL_EndGPURenderPass(i8*)
declare i1 @SDL_EnumerateDirectory(i8*, i64, i8*)
declare i1 @SDL_EnumerateProperties(i64, i64, i8*)
declare i1 @SDL_EnumerateStorageDirectory(i8*, i8*, i64, i8*)
declare i1 @SDL_EventEnabled(i32)
declare double @SDL_exp(double)
declare float @SDL_expf(float)
declare double @SDL_fabs(double)
declare float @SDL_fabsf(float)
declare i1 @SDL_FillSurfaceRect(i8*, i8*, i32)
declare i1 @SDL_FillSurfaceRects(i8*, i8*, i64, i32)
declare void @SDL_FilterEvents(i64, i8*)
declare i1 @SDL_FlashWindow(i8*, i64)
declare i1 @SDL_FlipSurface(i8*, i64)
declare double @SDL_floor(double)
declare float @SDL_floorf(float)
declare i1 @SDL_FlushAudioStream(i8*)
declare void @SDL_FlushEvent(i32)
declare void @SDL_FlushEvents(i32, i32)
declare i1 @SDL_FlushIO(i8*)
declare i1 @SDL_FlushRenderer(i8*)
declare double @SDL_fmod(double, double)
declare float @SDL_fmodf(float, float)
declare void @SDL_free(i8*)
declare i1 @SDL_GamepadConnected(i8*)
declare i1 @SDL_GamepadEventsEnabled()
declare i1 @SDL_GamepadHasAxis(i8*, i64)
declare i1 @SDL_GamepadHasButton(i8*, i64)
declare i1 @SDL_GamepadHasCapSense(i8*, i64)
declare i1 @SDL_GamepadHasSensor(i8*, i64)
declare i1 @SDL_GamepadSensorEnabled(i8*, i64)
declare void @SDL_GenerateMipmapsForGPUTexture(i8*, i8*)
declare i8* @SDL_GetAppMetadataProperty(i8*)
declare i64 @SDL_GetAssertionHandler(i8*)
declare i8* @SDL_GetAssertionReport()
declare i1 @SDL_GetAsyncIOResult(i8*, i8*)
declare i64 @SDL_GetAsyncIOSize(i8*)
declare i64 @SDL_GetAtomicInt(i8*)
declare i8* @SDL_GetAtomicPointer(i8*)
declare i32 @SDL_GetAtomicU32(i8*)
declare i8* @SDL_GetAudioDeviceChannelMap(i64, i8*)
declare i1 @SDL_GetAudioDeviceFormat(i64, i8*, i8*)
declare float @SDL_GetAudioDeviceGain(i64)
declare i8* @SDL_GetAudioDeviceName(i64)
declare i64 @SDL_GetAudioDeviceProperties(i64)
declare i8* @SDL_GetAudioDriver(i64)
declare i8* @SDL_GetAudioFormatName(i64)
declare i8* @SDL_GetAudioPlaybackDevices(i8*)
declare i8* @SDL_GetAudioRecordingDevices(i8*)
declare i64 @SDL_GetAudioStreamAvailable(i8*)
declare i64 @SDL_GetAudioStreamData(i8*, i8*, i64)
declare i64 @SDL_GetAudioStreamDevice(i8*)
declare i1 @SDL_GetAudioStreamFormat(i8*, i8*, i8*)
declare float @SDL_GetAudioStreamFrequencyRatio(i8*)
declare float @SDL_GetAudioStreamGain(i8*)
declare i8* @SDL_GetAudioStreamInputChannelMap(i8*, i8*)
declare i8* @SDL_GetAudioStreamOutputChannelMap(i8*, i8*)
declare i64 @SDL_GetAudioStreamProperties(i8*)
declare i64 @SDL_GetAudioStreamQueued(i8*)
declare i8* @SDL_GetBasePath()
declare i1 @SDL_GetBooleanProperty(i64, i8*, i1)
declare i8* @SDL_GetCameraDriver(i64)
declare i1 @SDL_GetCameraFormat(i8*, i8*)
declare i64 @SDL_GetCameraID(i8*)
declare i8* @SDL_GetCameraName(i64)
declare i64 @SDL_GetCameraPermissionState(i8*)
declare i64 @SDL_GetCameraPosition(i64)
declare i64 @SDL_GetCameraProperties(i8*)
declare i8* @SDL_GetCameras(i8*)
declare i8* @SDL_GetCameraSupportedFormats(i64, i8*)
declare i8* @SDL_GetClipboardData(i8*, i8*)
declare i8* @SDL_GetClipboardMimeTypes(i8*)
declare i8* @SDL_GetClipboardText()
declare i1 @SDL_GetClosestFullscreenDisplayMode(i64, i64, i64, float, i1, i8*)
declare i64 @SDL_GetCPUCacheLineSize()
declare i8* @SDL_GetCurrentAudioDriver()
declare i8* @SDL_GetCurrentCameraDriver()
declare i8* @SDL_GetCurrentDirectory()
declare i8* @SDL_GetCurrentDisplayMode(i64)
declare i64 @SDL_GetCurrentDisplayOrientation(i64)
declare i1 @SDL_GetCurrentRenderOutputSize(i8*, i8*, i8*)
declare i64 @SDL_GetCurrentThreadID()
declare i1 @SDL_GetCurrentTime(i8*)
declare i8* @SDL_GetCurrentVideoDriver()
declare i8* @SDL_GetCursor()
declare i1 @SDL_GetDateTimeLocalePreferences(i8*, i8*)
declare i64 @SDL_GetDayOfWeek(i64, i64, i64)
declare i64 @SDL_GetDayOfYear(i64, i64, i64)
declare i64 @SDL_GetDaysInMonth(i64, i64)
declare i64 @SDL_GetDefaultAssertionHandler()
declare i8* @SDL_GetDefaultCursor()
declare i64 @SDL_GetDefaultLogOutputFunction()
declare i1 @SDL_GetDefaultTextureScaleMode(i8*, i8*)
declare i8* @SDL_GetDesktopDisplayMode(i64)
declare i64 @SDL_GetDeviceFormFactor()
declare i8* @SDL_GetDeviceFormFactorName(i64)
declare i64 @SDL_GetDirect3D9AdapterIndex(i64)
declare i1 @SDL_GetDisplayBounds(i64, i8*)
declare float @SDL_GetDisplayContentScale(i64)
declare i64 @SDL_GetDisplayForPoint(i8*)
declare i64 @SDL_GetDisplayForRect(i8*)
declare i64 @SDL_GetDisplayForWindow(i8*)
declare i8* @SDL_GetDisplayName(i64)
declare i64 @SDL_GetDisplayProperties(i64)
declare i8* @SDL_GetDisplays(i8*)
declare i1 @SDL_GetDisplayUsableBounds(i64, i8*)
declare i1 @SDL_GetDXGIOutputInfo(i64, i8*, i8*)
declare i8* @SDL_getenv_unsafe(i8*)
declare i8* @SDL_getenv(i8*)
declare i8* @SDL_GetEnvironment()
declare i8* @SDL_GetEnvironmentVariable(i8*, i8*)
declare i8* @SDL_GetEnvironmentVariables(i8*)
declare i8* @SDL_GetError()
declare i64 @SDL_GetEventDescription(i8*, i8*, i64)
declare i1 @SDL_GetEventFilter(i8*, i8*)
declare float @SDL_GetFloatProperty(i64, i8*, float)
declare i8* @SDL_GetFullscreenDisplayModes(i64, i8*)
declare i8* @SDL_GetGamepadAppleSFSymbolsNameForAxis(i8*, i64)
declare i8* @SDL_GetGamepadAppleSFSymbolsNameForButton(i8*, i64)
declare i16 @SDL_GetGamepadAxis(i8*, i64)
declare i64 @SDL_GetGamepadAxisFromString(i8*)
declare i8* @SDL_GetGamepadBindings(i8*, i8*)
declare i1 @SDL_GetGamepadButton(i8*, i64)
declare i64 @SDL_GetGamepadButtonFromString(i8*)
declare i64 @SDL_GetGamepadButtonLabel(i8*, i64)
declare i64 @SDL_GetGamepadButtonLabelForType(i64, i64)
declare i1 @SDL_GetGamepadCapSense(i8*, i64)
declare i64 @SDL_GetGamepadConnectionState(i8*)
declare i16 @SDL_GetGamepadFirmwareVersion(i8*)
declare i8* @SDL_GetGamepadFromID(i64)
declare i8* @SDL_GetGamepadFromPlayerIndex(i64)
declare i64 @SDL_GetGamepadGUIDForID(i64)
declare i64 @SDL_GetGamepadID(i8*)
declare i8* @SDL_GetGamepadJoystick(i8*)
declare i8* @SDL_GetGamepadMapping(i8*)
declare i8* @SDL_GetGamepadMappingForGUID(i64)
declare i8* @SDL_GetGamepadMappingForID(i64)
declare i8* @SDL_GetGamepadMappings(i8*)
declare i8* @SDL_GetGamepadName(i8*)
declare i8* @SDL_GetGamepadNameForID(i64)
declare i8* @SDL_GetGamepadPath(i8*)
declare i8* @SDL_GetGamepadPathForID(i64)
declare i64 @SDL_GetGamepadPlayerIndex(i8*)
declare i64 @SDL_GetGamepadPlayerIndexForID(i64)
declare i64 @SDL_GetGamepadPowerInfo(i8*, i8*)
declare i16 @SDL_GetGamepadProduct(i8*)
declare i16 @SDL_GetGamepadProductForID(i64)
declare i16 @SDL_GetGamepadProductVersion(i8*)
declare i16 @SDL_GetGamepadProductVersionForID(i64)
declare i64 @SDL_GetGamepadProperties(i8*)
declare i8* @SDL_GetGamepads(i8*)
declare i1 @SDL_GetGamepadSensorData(i8*, i64, i8*, i64)
declare float @SDL_GetGamepadSensorDataRate(i8*, i64)
declare i8* @SDL_GetGamepadSerial(i8*)
declare i64 @SDL_GetGamepadSteamHandle(i8*)
declare i8* @SDL_GetGamepadStringForAxis(i64)
declare i8* @SDL_GetGamepadStringForButton(i64)
declare i8* @SDL_GetGamepadStringForType(i64)
declare i1 @SDL_GetGamepadTouchpadFinger(i8*, i64, i64, i8*, i8*, i8*, i8*)
declare i64 @SDL_GetGamepadType(i8*)
declare i64 @SDL_GetGamepadTypeForID(i64)
declare i64 @SDL_GetGamepadTypeFromString(i8*)
declare i16 @SDL_GetGamepadVendor(i8*)
declare i16 @SDL_GetGamepadVendorForID(i64)
declare i64 @SDL_GetGlobalMouseState(i8*, i8*)
declare i64 @SDL_GetGlobalProperties()
declare i8* @SDL_GetGPUDeviceDriver(i8*)
declare i64 @SDL_GetGPUDeviceProperties(i8*)
declare i8* @SDL_GetGPUDriver(i64)
declare i8* @SDL_GetGPURendererDevice(i8*)
declare i64 @SDL_GetGPUShaderFormats(i8*)
declare i64 @SDL_GetGPUSwapchainTextureFormat(i8*, i8*)
declare i64 @SDL_GetGPUTextureFormatFromPixelFormat(i64)
declare i8* @SDL_GetGrabbedWindow()
declare i1 @SDL_GetHapticEffectStatus(i8*, i64)
declare i32 @SDL_GetHapticFeatures(i8*)
declare i8* @SDL_GetHapticFromID(i64)
declare i64 @SDL_GetHapticID(i8*)
declare i8* @SDL_GetHapticName(i8*)
declare i8* @SDL_GetHapticNameForID(i64)
declare i8* @SDL_GetHaptics(i8*)
declare i8* @SDL_GetHint(i8*)
declare i1 @SDL_GetHintBoolean(i8*, i1)
declare i64 @SDL_GetIOProperties(i8*)
declare i64 @SDL_GetIOSize(i8*)
declare i64 @SDL_GetIOStatus(i8*)
declare i16 @SDL_GetJoystickAxis(i8*, i64)
declare i1 @SDL_GetJoystickAxisInitialState(i8*, i64, i8*)
declare i1 @SDL_GetJoystickBall(i8*, i64, i8*, i8*)
declare i1 @SDL_GetJoystickButton(i8*, i64)
declare i64 @SDL_GetJoystickConnectionState(i8*)
declare i16 @SDL_GetJoystickFirmwareVersion(i8*)
declare i8* @SDL_GetJoystickFromID(i64)
declare i8* @SDL_GetJoystickFromPlayerIndex(i64)
declare i64 @SDL_GetJoystickGUID(i8*)
declare i64 @SDL_GetJoystickGUIDForID(i64)
declare void @SDL_GetJoystickGUIDInfo(i64, i8*, i8*, i8*, i8*)
declare i8 @SDL_GetJoystickHat(i8*, i64)
declare i64 @SDL_GetJoystickID(i8*)
declare i8* @SDL_GetJoystickName(i8*)
declare i8* @SDL_GetJoystickNameForID(i64)
declare i8* @SDL_GetJoystickPath(i8*)
declare i8* @SDL_GetJoystickPathForID(i64)
declare i64 @SDL_GetJoystickPlayerIndex(i8*)
declare i64 @SDL_GetJoystickPlayerIndexForID(i64)
declare i64 @SDL_GetJoystickPowerInfo(i8*, i8*)
declare i16 @SDL_GetJoystickProduct(i8*)
declare i16 @SDL_GetJoystickProductForID(i64)
declare i16 @SDL_GetJoystickProductVersion(i8*)
declare i16 @SDL_GetJoystickProductVersionForID(i64)
declare i64 @SDL_GetJoystickProperties(i8*)
declare i8* @SDL_GetJoysticks(i8*)
declare i1 @SDL_GetJoystickSensorData(i8*, i64, i8*, i64)
declare float @SDL_GetJoystickSensorDataRate(i8*, i64)
declare i8* @SDL_GetJoystickSerial(i8*)
declare i64 @SDL_GetJoystickType(i8*)
declare i64 @SDL_GetJoystickTypeForID(i64)
declare i16 @SDL_GetJoystickVendor(i8*)
declare i16 @SDL_GetJoystickVendorForID(i64)
declare i8* @SDL_GetKeyboardFocus()
declare i8* @SDL_GetKeyboardNameForID(i64)
declare i8* @SDL_GetKeyboards(i8*)
declare i8* @SDL_GetKeyboardState(i8*)
declare i64 @SDL_GetKeyFromName(i8*)
declare i64 @SDL_GetKeyFromScancode(i64, i64, i1)
declare i8* @SDL_GetKeyName(i64)
declare void @SDL_GetLogOutputFunction(i8*, i8*)
declare i64 @SDL_GetLogPriority(i64)
declare i1 @SDL_GetMasksForPixelFormat(i64, i8*, i8*, i8*, i8*, i8*)
declare i64 @SDL_GetMaxHapticEffects(i8*)
declare i64 @SDL_GetMaxHapticEffectsPlaying(i8*)
declare void @SDL_GetMemoryFunctions(i8*, i8*, i8*, i8*)
declare i8* @SDL_GetMice(i8*)
declare i64 @SDL_GetModState()
declare i8* @SDL_GetMouseFocus()
declare i8* @SDL_GetMouseNameForID(i64)
declare i64 @SDL_GetMouseState(i8*, i8*)
declare i64 @SDL_GetNaturalDisplayOrientation(i64)
declare i64 @SDL_GetNumAllocations()
declare i64 @SDL_GetNumAudioDrivers()
declare i64 @SDL_GetNumberProperty(i64, i8*, i64)
declare i64 @SDL_GetNumCameraDrivers()
declare i64 @SDL_GetNumGamepadTouchpadFingers(i8*, i64)
declare i64 @SDL_GetNumGamepadTouchpads(i8*)
declare i64 @SDL_GetNumGPUDrivers()
declare i64 @SDL_GetNumHapticAxes(i8*)
declare i64 @SDL_GetNumJoystickAxes(i8*)
declare i64 @SDL_GetNumJoystickBalls(i8*)
declare i64 @SDL_GetNumJoystickButtons(i8*)
declare i64 @SDL_GetNumJoystickHats(i8*)
declare i64 @SDL_GetNumLogicalCPUCores()
declare i64 @SDL_GetNumProperties(i64)
declare i64 @SDL_GetNumRenderDrivers()
declare i64 @SDL_GetNumVideoDrivers()
declare void @SDL_GetOriginalMemoryFunctions(i8*, i8*, i8*, i8*)
declare i1 @SDL_GetPathInfo(i8*, i8*)
declare i64 @SDL_GetPenDeviceType(i64)
declare i64 @SDL_GetPerformanceCounter()
declare i64 @SDL_GetPerformanceFrequency()
declare i8* @SDL_GetPixelFormatDetails(i64)
declare i64 @SDL_GetPixelFormatForMasks(i64, i32, i32, i32, i32)
declare i64 @SDL_GetPixelFormatFromGPUTextureFormat(i64)
declare i8* @SDL_GetPixelFormatName(i64)
declare i8* @SDL_GetPlatform()
declare i8* @SDL_GetPointerProperty(i64, i8*, i8*)
declare i64 @SDL_GetPowerInfo(i8*, i8*)
declare i8* @SDL_GetPreferredLocales(i8*)
declare i8* @SDL_GetPrefPath(i8*, i8*)
declare i64 @SDL_GetPrimaryDisplay()
declare i8* @SDL_GetPrimarySelectionText()
declare i8* @SDL_GetProcessInput(i8*)
declare i8* @SDL_GetProcessOutput(i8*)
declare i64 @SDL_GetProcessProperties(i8*)
declare i64 @SDL_GetPropertyType(i64, i8*)
declare i64 @SDL_GetRealGamepadType(i8*)
declare i64 @SDL_GetRealGamepadTypeForID(i64)
declare i1 @SDL_GetRectAndLineIntersection(i8*, i8*, i8*, i8*, i8*)
declare i1 @SDL_GetRectAndLineIntersectionFloat(i8*, i8*, i8*, i8*, i8*)
declare i1 @SDL_GetRectEnclosingPoints(i8*, i64, i8*, i8*)
declare i1 @SDL_GetRectEnclosingPointsFloat(i8*, i64, i8*, i8*)
declare i1 @SDL_GetRectIntersection(i8*, i8*, i8*)
declare i1 @SDL_GetRectIntersectionFloat(i8*, i8*, i8*)
declare i1 @SDL_GetRectUnion(i8*, i8*, i8*)
declare i1 @SDL_GetRectUnionFloat(i8*, i8*, i8*)
declare i64 @SDL_GetRelativeMouseState(i8*, i8*)
declare i1 @SDL_GetRenderClipRect(i8*, i8*)
declare i1 @SDL_GetRenderClipRectFloat(i8*, i8*)
declare i1 @SDL_GetRenderColorScale(i8*, i8*)
declare i1 @SDL_GetRenderDrawBlendMode(i8*, i8*)
declare i1 @SDL_GetRenderDrawColor(i8*, i8*, i8*, i8*, i8*)
declare i1 @SDL_GetRenderDrawColorFloat(i8*, i8*, i8*, i8*, i8*)
declare i8* @SDL_GetRenderDriver(i64)
declare i8* @SDL_GetRenderer(i8*)
declare i8* @SDL_GetRendererFromTexture(i8*)
declare i8* @SDL_GetRendererName(i8*)
declare i64 @SDL_GetRendererProperties(i8*)
declare i1 @SDL_GetRenderHDRHeadroom(i8*, i8*)
declare i1 @SDL_GetRenderLogicalPresentation(i8*, i8*, i8*, i8*)
declare i1 @SDL_GetRenderLogicalPresentationRect(i8*, i8*)
declare i8* @SDL_GetRenderMetalCommandEncoder(i8*)
declare i8* @SDL_GetRenderMetalLayer(i8*)
declare i1 @SDL_GetRenderOutputSize(i8*, i8*, i8*)
declare i1 @SDL_GetRenderSafeArea(i8*, i8*)
declare i1 @SDL_GetRenderScale(i8*, i8*, i8*)
declare i8* @SDL_GetRenderTarget(i8*)
declare i1 @SDL_GetRenderTextureAddressMode(i8*, i8*, i8*)
declare i1 @SDL_GetRenderViewport(i8*, i8*)
declare i1 @SDL_GetRenderViewportFloat(i8*, i8*)
declare i1 @SDL_GetRenderVSync(i8*, i8*)
declare i8* @SDL_GetRenderWindow(i8*)
declare i8* @SDL_GetRevision()
declare void @SDL_GetRGB(i32, i8*, i8*, i8*, i8*, i8*)
declare void @SDL_GetRGBA(i32, i8*, i8*, i8*, i8*, i8*, i8*)
declare i64 @SDL_GetSandbox()
declare i64 @SDL_GetScancodeFromKey(i64, i8*)
declare i64 @SDL_GetScancodeFromName(i8*)
declare i8* @SDL_GetScancodeName(i64)
declare i32 @SDL_GetSemaphoreValue(i8*)
declare i1 @SDL_GetSensorData(i8*, i8*, i64)
declare i8* @SDL_GetSensorFromID(i64)
declare i64 @SDL_GetSensorID(i8*)
declare i8* @SDL_GetSensorName(i8*)
declare i8* @SDL_GetSensorNameForID(i64)
declare i64 @SDL_GetSensorNonPortableType(i8*)
declare i64 @SDL_GetSensorNonPortableTypeForID(i64)
declare i64 @SDL_GetSensorProperties(i8*)
declare i8* @SDL_GetSensors(i8*)
declare i64 @SDL_GetSensorType(i8*)
declare i64 @SDL_GetSensorTypeForID(i64)
declare i64 @SDL_GetSilenceValueForFormat(i64)
declare i64 @SDL_GetSIMDAlignment()
declare i1 @SDL_GetStorageFileSize(i8*, i8*, i8*)
declare i1 @SDL_GetStoragePathInfo(i8*, i8*, i8*)
declare i64 @SDL_GetStorageSpaceRemaining(i8*)
declare i8* @SDL_GetStringProperty(i64, i8*, i8*)
declare i1 @SDL_GetSurfaceAlphaMod(i8*, i8*)
declare i1 @SDL_GetSurfaceBlendMode(i8*, i8*)
declare i1 @SDL_GetSurfaceClipRect(i8*, i8*)
declare i1 @SDL_GetSurfaceColorKey(i8*, i8*)
declare i1 @SDL_GetSurfaceColorMod(i8*, i8*, i8*, i8*)
declare i64 @SDL_GetSurfaceColorspace(i8*)
declare i8* @SDL_GetSurfaceImages(i8*, i8*)
declare i8* @SDL_GetSurfacePalette(i8*)
declare i64 @SDL_GetSurfaceProperties(i8*)
declare i64 @SDL_GetSystemPageSize()
declare i64 @SDL_GetSystemRAM()
declare i64 @SDL_GetSystemTheme()
declare i1 @SDL_GetTextInputArea(i8*, i8*, i8*)
declare i1 @SDL_GetTextureAlphaMod(i8*, i8*)
declare i1 @SDL_GetTextureAlphaModFloat(i8*, i8*)
declare i1 @SDL_GetTextureBlendMode(i8*, i8*)
declare i1 @SDL_GetTextureColorMod(i8*, i8*, i8*, i8*)
declare i1 @SDL_GetTextureColorModFloat(i8*, i8*, i8*, i8*)
declare i8* @SDL_GetTexturePalette(i8*)
declare i64 @SDL_GetTextureProperties(i8*)
declare i1 @SDL_GetTextureScaleMode(i8*, i8*)
declare i1 @SDL_GetTextureSize(i8*, i8*, i8*)
declare i64 @SDL_GetThreadID(i8*)
declare i8* @SDL_GetThreadName(i8*)
declare i64 @SDL_GetThreadState(i8*)
declare i64 @SDL_GetTicks()
declare i64 @SDL_GetTicksNS()
declare i8* @SDL_GetTLS(i8*)
declare i8* @SDL_GetTouchDeviceName(i64)
declare i8* @SDL_GetTouchDevices(i8*)
declare i64 @SDL_GetTouchDeviceType(i64)
declare i8* @SDL_GetTouchFingers(i64, i8*)
declare i8* @SDL_GetTrayEntries(i8*, i8*)
declare i1 @SDL_GetTrayEntryChecked(i8*)
declare i1 @SDL_GetTrayEntryEnabled(i8*)
declare i8* @SDL_GetTrayEntryLabel(i8*)
declare i8* @SDL_GetTrayEntryParent(i8*)
declare i8* @SDL_GetTrayMenu(i8*)
declare i8* @SDL_GetTrayMenuParentEntry(i8*)
declare i8* @SDL_GetTrayMenuParentTray(i8*)
declare i8* @SDL_GetTraySubmenu(i8*)
declare i8* @SDL_GetUserFolder(i64)
declare i64 @SDL_GetVersion()
declare i8* @SDL_GetVideoDriver(i64)
declare i1 @SDL_GetWindowAspectRatio(i8*, i8*, i8*)
declare i1 @SDL_GetWindowBordersSize(i8*, i8*, i8*, i8*, i8*)
declare float @SDL_GetWindowDisplayScale(i8*)
declare i64 @SDL_GetWindowFlags(i8*)
declare i8* @SDL_GetWindowFromEvent(i8*)
declare i8* @SDL_GetWindowFromID(i64)
declare i8* @SDL_GetWindowFullscreenMode(i8*)
declare i8* @SDL_GetWindowICCProfile(i8*, i8*)
declare i64 @SDL_GetWindowID(i8*)
declare i1 @SDL_GetWindowKeyboardGrab(i8*)
declare i1 @SDL_GetWindowMaximumSize(i8*, i8*, i8*)
declare i1 @SDL_GetWindowMinimumSize(i8*, i8*, i8*)
declare i1 @SDL_GetWindowMouseGrab(i8*)
declare i8* @SDL_GetWindowMouseRect(i8*)
declare float @SDL_GetWindowOpacity(i8*)
declare i8* @SDL_GetWindowParent(i8*)
declare float @SDL_GetWindowPixelDensity(i8*)
declare i64 @SDL_GetWindowPixelFormat(i8*)
declare i1 @SDL_GetWindowPosition(i8*, i8*, i8*)
declare i64 @SDL_GetWindowProgressState(i8*)
declare float @SDL_GetWindowProgressValue(i8*)
declare i64 @SDL_GetWindowProperties(i8*)
declare i1 @SDL_GetWindowRelativeMouseMode(i8*)
declare i8* @SDL_GetWindows(i8*)
declare i1 @SDL_GetWindowSafeArea(i8*, i8*)
declare i1 @SDL_GetWindowSize(i8*, i8*, i8*)
declare i1 @SDL_GetWindowSizeInPixels(i8*, i8*, i8*)
declare i8* @SDL_GetWindowSurface(i8*)
declare i1 @SDL_GetWindowSurfaceVSync(i8*, i8*)
declare i8* @SDL_GetWindowTitle(i8*)
declare i64 @SDL_GL_CreateContext(i8*)
declare i1 @SDL_GL_DestroyContext(i64)
declare i1 @SDL_GL_ExtensionSupported(i8*)
declare i1 @SDL_GL_GetAttribute(i64, i8*)
declare i64 @SDL_GL_GetCurrentContext()
declare i8* @SDL_GL_GetCurrentWindow()
declare i64 @SDL_GL_GetProcAddress(i8*)
declare i1 @SDL_GL_GetSwapInterval(i8*)
declare i1 @SDL_GL_LoadLibrary(i8*)
declare i1 @SDL_GL_MakeCurrent(i8*, i64)
declare void @SDL_GL_ResetAttributes()
declare i1 @SDL_GL_SetAttribute(i64, i64)
declare i1 @SDL_GL_SetSwapInterval(i64)
declare i1 @SDL_GL_SwapWindow(i8*)
declare void @SDL_GL_UnloadLibrary()
declare i8* @SDL_GlobDirectory(i8*, i8*, i64, i8*)
declare i8* @SDL_GlobStorageDirectory(i8*, i8*, i8*, i64, i8*)
declare i1 @SDL_GPUSupportsProperties(i64)
declare i1 @SDL_GPUSupportsShaderFormats(i64, i8*)
declare i32 @SDL_GPUTextureFormatTexelBlockSize(i64)
declare i1 @SDL_GPUTextureSupportsFormat(i8*, i64, i64, i64)
declare i1 @SDL_GPUTextureSupportsSampleCount(i8*, i64, i64)
declare void @SDL_GUIDToString(i64, i8*, i64)
declare i1 @SDL_HapticEffectSupported(i8*, i8*)
declare i1 @SDL_HapticRumbleSupported(i8*)
declare i1 @SDL_HasAltiVec()
declare i1 @SDL_HasARMSIMD()
declare i1 @SDL_HasAVX()
declare i1 @SDL_HasAVX2()
declare i1 @SDL_HasAVX512F()
declare i1 @SDL_HasClipboardData(i8*)
declare i1 @SDL_HasClipboardText()
declare i1 @SDL_HasEvent(i32)
declare i1 @SDL_HasEvents(i32, i32)
declare i1 @SDL_HasGamepad()
declare i1 @SDL_HasJoystick()
declare i1 @SDL_HasKeyboard()
declare i1 @SDL_HasLASX()
declare i1 @SDL_HasLSX()
declare i1 @SDL_HasMMX()
declare i1 @SDL_HasMouse()
declare i1 @SDL_HasNEON()
declare i1 @SDL_HasPrimarySelectionText()
declare i1 @SDL_HasProperty(i64, i8*)
declare i1 @SDL_HasRectIntersection(i8*, i8*)
declare i1 @SDL_HasRectIntersectionFloat(i8*, i8*)
declare i1 @SDL_HasScreenKeyboardSupport()
declare i1 @SDL_HasSSE()
declare i1 @SDL_HasSSE2()
declare i1 @SDL_HasSSE3()
declare i1 @SDL_HasSSE41()
declare i1 @SDL_HasSSE42()
declare i1 @SDL_HasSVE2()
declare void @SDL_hid_ble_scan(i1)
declare i64 @SDL_hid_close(i8*)
declare i32 @SDL_hid_device_change_count()
declare i8* @SDL_hid_enumerate(i16, i16)
declare i64 @SDL_hid_exit()
declare void @SDL_hid_free_enumeration(i8*)
declare i8* @SDL_hid_get_device_info(i8*)
declare i64 @SDL_hid_get_feature_report(i8*, i8*, i64)
declare i64 @SDL_hid_get_indexed_string(i8*, i64, i8*, i64)
declare i64 @SDL_hid_get_input_report(i8*, i8*, i64)
declare i64 @SDL_hid_get_manufacturer_string(i8*, i8*, i64)
declare i64 @SDL_hid_get_product_string(i8*, i8*, i64)
declare i64 @SDL_hid_get_properties(i8*)
declare i64 @SDL_hid_get_report_descriptor(i8*, i8*, i64)
declare i64 @SDL_hid_get_serial_number_string(i8*, i8*, i64)
declare i64 @SDL_hid_init()
declare i8* @SDL_hid_open_path(i8*)
declare i8* @SDL_hid_open(i16, i16, i8*)
declare i64 @SDL_hid_read_timeout(i8*, i8*, i64, i64)
declare i64 @SDL_hid_read(i8*, i8*, i64)
declare i64 @SDL_hid_send_feature_report(i8*, i8*, i64)
declare i64 @SDL_hid_set_nonblocking(i8*, i64)
declare i64 @SDL_hid_write(i8*, i8*, i64)
declare i1 @SDL_HideCursor()
declare i1 @SDL_HideWindow(i8*)
declare i64 @SDL_iconv_close(i64)
declare i64 @SDL_iconv_open(i8*, i8*)
declare i8* @SDL_iconv_string(i8*, i8*, i8*, i64)
declare i64 @SDL_iconv(i64, i8*, i8*, i8*, i8*)
declare i1 @SDL_Init(i64)
declare i1 @SDL_InitHapticRumble(i8*)
declare i1 @SDL_InitSubSystem(i64)
declare void @SDL_InsertGPUDebugLabel(i8*, i8*)
declare i8* @SDL_InsertTrayEntryAt(i8*, i64, i8*, i64)
declare i8* @SDL_IOFromConstMem(i8*, i64)
declare i8* @SDL_IOFromDynamicMem()
declare i8* @SDL_IOFromFile(i8*, i8*)
declare i8* @SDL_IOFromMem(i8*, i64)
declare i64 @SDL_IOprintf(i8*, i8*, i64, i64)
declare i64 @SDL_IOvprintf(i8*, i8*, i64, i64, i64)
declare i64 @SDL_isalnum(i64)
declare i64 @SDL_isalpha(i64)
declare i1 @SDL_IsAudioDevicePhysical(i64)
declare i1 @SDL_IsAudioDevicePlayback(i64)
declare i64 @SDL_isblank(i64)
declare i64 @SDL_iscntrl(i64)
declare i64 @SDL_isdigit(i64)
declare i1 @SDL_IsGamepad(i64)
declare i64 @SDL_isgraph(i64)
declare i64 @SDL_isinf(double)
declare i64 @SDL_isinff(float)
declare i1 @SDL_IsJoystickHaptic(i8*)
declare i1 @SDL_IsJoystickVirtual(i64)
declare i64 @SDL_islower(i64)
declare i1 @SDL_IsMainThread()
declare i1 @SDL_IsMouseHaptic()
declare i64 @SDL_isnan(double)
declare i64 @SDL_isnanf(float)
declare i1 @SDL_IsPhone()
declare i64 @SDL_isprint(i64)
declare i64 @SDL_ispunct(i64)
declare i64 @SDL_isspace(i64)
declare i1 @SDL_IsTablet()
declare i1 @SDL_IsTV()
declare i64 @SDL_isupper(i64)
declare i64 @SDL_isxdigit(i64)
declare i8* @SDL_itoa(i64, i8*, i64)
declare i1 @SDL_JoystickConnected(i8*)
declare i1 @SDL_JoystickEventsEnabled()
declare i1 @SDL_JoystickHasSensor(i8*, i64)
declare i1 @SDL_JoystickSensorEnabled(i8*, i64)
declare i1 @SDL_KillProcess(i8*, i1)
declare i8* @SDL_lltoa(i64, i8*, i64)
declare i8* @SDL_LoadBMP_IO(i8*, i1)
declare i8* @SDL_LoadBMP(i8*)
declare i8* @SDL_LoadFile_IO(i8*, i8*, i1)
declare i8* @SDL_LoadFile(i8*, i8*)
declare i1 @SDL_LoadFileAsync(i8*, i8*, i8*)
declare i64 @SDL_LoadFunction(i8*, i8*)
declare i8* @SDL_LoadJPG_IO(i8*, i1)
declare i8* @SDL_LoadJPG(i8*)
declare i8* @SDL_LoadObject(i8*)
declare i8* @SDL_LoadPNG_IO(i8*, i1)
declare i8* @SDL_LoadPNG(i8*)
declare i8* @SDL_LoadSurface_IO(i8*, i1)
declare i8* @SDL_LoadSurface(i8*)
declare i1 @SDL_LoadWAV_IO(i8*, i1, i8*, i8*, i8*)
declare i1 @SDL_LoadWAV(i8*, i8*, i8*, i8*)
declare i1 @SDL_LockAudioStream(i8*)
declare void @SDL_LockJoysticks()
declare void @SDL_LockMutex(i8*)
declare i1 @SDL_LockProperties(i64)
declare void @SDL_LockRWLockForReading(i8*)
declare void @SDL_LockRWLockForWriting(i8*)
declare void @SDL_LockSpinlock(i8*)
declare i1 @SDL_LockSurface(i8*)
declare i1 @SDL_LockTexture(i8*, i8*, i8*, i8*)
declare i1 @SDL_LockTextureToSurface(i8*, i8*, i8*)
declare void @SDL_Log(i8*, i64, i64)
declare double @SDL_log(double)
declare double @SDL_log10(double)
declare float @SDL_log10f(float)
declare void @SDL_LogCritical(i64, i8*, i64, i64)
declare void @SDL_LogDebug(i64, i8*, i64, i64)
declare void @SDL_LogError(i64, i8*, i64, i64)
declare float @SDL_logf(float)
declare void @SDL_LogInfo(i64, i8*, i64, i64)
declare void @SDL_LogMessage(i64, i64, i8*, i64, i64)
declare void @SDL_LogMessageV(i64, i64, i8*, i64, i64, i64)
declare void @SDL_LogTrace(i64, i8*, i64, i64)
declare void @SDL_LogVerbose(i64, i8*, i64, i64)
declare void @SDL_LogWarn(i64, i8*, i64, i64)
declare i64 @SDL_lround(double)
declare i64 @SDL_lroundf(float)
declare i8* @SDL_ltoa(i64, i8*, i64)
declare i8* @SDL_malloc(i64)
declare i8* @SDL_MapGPUTransferBuffer(i8*, i8*, i1)
declare i32 @SDL_MapRGB(i8*, i8*, i8, i8, i8)
declare i32 @SDL_MapRGBA(i8*, i8*, i8, i8, i8, i8)
declare i32 @SDL_MapSurfaceRGB(i8*, i8, i8, i8)
declare i32 @SDL_MapSurfaceRGBA(i8*, i8, i8, i8, i8)
declare i1 @SDL_MaximizeWindow(i8*)
declare i64 @SDL_memcmp(i8*, i8*, i64)
declare i8* @SDL_memcpy(i8*, i8*, i64)
declare i8* @SDL_memmove(i8*, i8*, i64)
declare void @SDL_MemoryBarrierAcquireFunction()
declare void @SDL_MemoryBarrierReleaseFunction()
declare i8* @SDL_memset(i8*, i64, i64)
declare i8* @SDL_memset4(i8*, i32, i64)
declare i64 @SDL_Metal_CreateView(i8*)
declare void @SDL_Metal_DestroyView(i64)
declare i8* @SDL_Metal_GetLayer(i64)
declare i1 @SDL_MinimizeWindow(i8*)
declare i1 @SDL_MixAudio(i8*, i8*, i64, i32, float)
declare double @SDL_modf(double, i8*)
declare float @SDL_modff(float, i8*)
declare i32 @SDL_murmur3_32(i8*, i64, i32)
declare void @SDL_OnApplicationDidEnterBackground()
declare void @SDL_OnApplicationDidEnterForeground()
declare void @SDL_OnApplicationDidReceiveMemoryWarning()
declare void @SDL_OnApplicationWillEnterBackground()
declare void @SDL_OnApplicationWillEnterForeground()
declare void @SDL_OnApplicationWillTerminate()
declare i64 @SDL_OpenAudioDevice(i64, i8*)
declare i8* @SDL_OpenAudioDeviceStream(i64, i8*, i64, i8*)
declare i8* @SDL_OpenCamera(i64, i8*)
declare i8* @SDL_OpenFileStorage(i8*)
declare i8* @SDL_OpenGamepad(i64)
declare i8* @SDL_OpenHaptic(i64)
declare i8* @SDL_OpenHapticFromJoystick(i8*)
declare i8* @SDL_OpenHapticFromMouse()
declare i8* @SDL_OpenIO(i8*, i8*)
declare i8* @SDL_OpenJoystick(i64)
declare i8* @SDL_OpenSensor(i64)
declare i8* @SDL_OpenStorage(i8*, i8*)
declare i8* @SDL_OpenTitleStorage(i8*, i64)
declare i1 @SDL_OpenURL(i8*)
declare i8* @SDL_OpenUserStorage(i8*, i8*, i64)
declare i1 @SDL_OutOfMemory()
declare i1 @SDL_PauseAudioDevice(i64)
declare i1 @SDL_PauseAudioStreamDevice(i8*)
declare i1 @SDL_PauseHaptic(i8*)
declare i64 @SDL_PeepEvents(i8*, i64, i64, i32, i32)
declare i1 @SDL_PlayHapticRumble(i8*, float, i32)
declare i1 @SDL_PollEvent(i8*)
declare void @SDL_PopGPUDebugGroup(i8*)
declare double @SDL_pow(double, double)
declare float @SDL_powf(float, float)
declare i1 @SDL_PremultiplyAlpha(i64, i64, i64, i8*, i64, i64, i8*, i64, i1)
declare i1 @SDL_PremultiplySurfaceAlpha(i8*, i1)
declare void @SDL_PumpEvents()
declare i1 @SDL_PushEvent(i8*)
declare void @SDL_PushGPUComputeUniformData(i8*, i32, i8*, i32)
declare void @SDL_PushGPUDebugGroup(i8*, i8*)
declare void @SDL_PushGPUFragmentUniformData(i8*, i32, i8*, i32)
declare void @SDL_PushGPUVertexUniformData(i8*, i32, i8*, i32)
declare i1 @SDL_PutAudioStreamData(i8*, i8*, i64)
declare i1 @SDL_PutAudioStreamDataNoCopy(i8*, i8*, i64, i64, i8*)
declare i1 @SDL_PutAudioStreamPlanarData(i8*, i8*, i64, i64)
declare void @SDL_qsort_r(i8*, i64, i64, i64, i8*)
declare void @SDL_qsort(i8*, i64, i64, i64)
declare i1 @SDL_QueryGPUFence(i8*, i8*)
declare void @SDL_Quit()
declare void @SDL_QuitSubSystem(i64)
declare i1 @SDL_RaiseWindow(i8*)
declare i32 @SDL_rand_bits_r(i8*)
declare i32 @SDL_rand_bits()
declare i32 @SDL_rand_r(i8*, i32)
declare i32 @SDL_rand(i32)
declare float @SDL_randf_r(i8*)
declare float @SDL_randf()
declare i1 @SDL_ReadAsyncIO(i8*, i8*, i64, i64, i8*, i8*)
declare i64 @SDL_ReadIO(i8*, i8*, i64)
declare i8* @SDL_ReadProcess(i8*, i8*, i8*)
declare i1 @SDL_ReadS16BE(i8*, i8*)
declare i1 @SDL_ReadS16LE(i8*, i8*)
declare i1 @SDL_ReadS32BE(i8*, i8*)
declare i1 @SDL_ReadS32LE(i8*, i8*)
declare i1 @SDL_ReadS64BE(i8*, i8*)
declare i1 @SDL_ReadS64LE(i8*, i8*)
declare i1 @SDL_ReadS8(i8*, i8*)
declare i1 @SDL_ReadStorageFile(i8*, i8*, i8*, i64)
declare i1 @SDL_ReadSurfacePixel(i8*, i64, i64, i8*, i8*, i8*, i8*)
declare i1 @SDL_ReadSurfacePixelFloat(i8*, i64, i64, i8*, i8*, i8*, i8*)
declare i1 @SDL_ReadU16BE(i8*, i8*)
declare i1 @SDL_ReadU16LE(i8*, i8*)
declare i1 @SDL_ReadU32BE(i8*, i8*)
declare i1 @SDL_ReadU32LE(i8*, i8*)
declare i1 @SDL_ReadU64BE(i8*, i8*)
declare i1 @SDL_ReadU64LE(i8*, i8*)
declare i1 @SDL_ReadU8(i8*, i8*)
declare i8* @SDL_realloc(i8*, i64)
declare i32 @SDL_RegisterEvents(i64)
declare void @SDL_ReleaseCameraFrame(i8*, i8*)
declare void @SDL_ReleaseGPUBuffer(i8*, i8*)
declare void @SDL_ReleaseGPUComputePipeline(i8*, i8*)
declare void @SDL_ReleaseGPUFence(i8*, i8*)
declare void @SDL_ReleaseGPUGraphicsPipeline(i8*, i8*)
declare void @SDL_ReleaseGPUSampler(i8*, i8*)
declare void @SDL_ReleaseGPUShader(i8*, i8*)
declare void @SDL_ReleaseGPUTexture(i8*, i8*)
declare void @SDL_ReleaseGPUTransferBuffer(i8*, i8*)
declare void @SDL_ReleaseWindowFromGPUDevice(i8*, i8*)
declare i1 @SDL_ReloadGamepadMappings()
declare void @SDL_RemoveEventWatch(i64, i8*)
declare void @SDL_RemoveHintCallback(i8*, i64, i8*)
declare i1 @SDL_RemoveNotification(i64)
declare i1 @SDL_RemovePath(i8*)
declare i1 @SDL_RemoveStoragePath(i8*, i8*)
declare void @SDL_RemoveSurfaceAlternateImages(i8*)
declare i1 @SDL_RemoveTimer(i64)
declare void @SDL_RemoveTrayEntry(i8*)
declare i1 @SDL_RenamePath(i8*, i8*)
declare i1 @SDL_RenameStoragePath(i8*, i8*, i8*)
declare i1 @SDL_RenderClear(i8*)
declare i1 @SDL_RenderClipEnabled(i8*)
declare i1 @SDL_RenderCoordinatesFromWindow(i8*, float, float, i8*, i8*)
declare i1 @SDL_RenderCoordinatesToWindow(i8*, float, float, i8*, i8*)
declare i1 @SDL_RenderDebugText(i8*, float, float, i8*)
declare i1 @SDL_RenderDebugTextFormat(i8*, float, float, i8*, i64, i64)
declare i1 @SDL_RenderFillRect(i8*, i8*)
declare i1 @SDL_RenderFillRects(i8*, i8*, i64)
declare i1 @SDL_RenderGeometry(i8*, i8*, i8*, i64, i8*, i64)
declare i1 @SDL_RenderGeometryRaw(i8*, i8*, i8*, i64, i8*, i64, i8*, i64, i64, i8*, i64, i64)
declare i1 @SDL_RenderLine(i8*, float, float, float, float)
declare i1 @SDL_RenderLines(i8*, i8*, i64)
declare i1 @SDL_RenderPoint(i8*, float, float)
declare i1 @SDL_RenderPoints(i8*, i8*, i64)
declare i1 @SDL_RenderPresent(i8*)
declare i8* @SDL_RenderReadPixels(i8*, i8*)
declare i1 @SDL_RenderRect(i8*, i8*)
declare i1 @SDL_RenderRects(i8*, i8*, i64)
declare i1 @SDL_RenderTexture(i8*, i8*, i8*, i8*)
declare i1 @SDL_RenderTexture9Grid(i8*, i8*, i8*, float, float, float, float, float, i8*)
declare i1 @SDL_RenderTexture9GridTiled(i8*, i8*, i8*, float, float, float, float, float, i8*, float)
declare i1 @SDL_RenderTextureAffine(i8*, i8*, i8*, i8*, i8*, i8*)
declare i1 @SDL_RenderTextureRotated(i8*, i8*, i8*, i8*, double, i8*, i64)
declare i1 @SDL_RenderTextureTiled(i8*, i8*, i8*, float, i8*)
declare i1 @SDL_RenderViewportSet(i8*)
declare i64 @SDL_ReportAssertion(i8*, i8*, i8*, i64)
declare i1 @SDL_RequestNotificationPermission()
declare void @SDL_ResetAssertionReport()
declare i1 @SDL_ResetHint(i8*)
declare void @SDL_ResetHints()
declare void @SDL_ResetKeyboard()
declare void @SDL_ResetLogPriorities()
declare i1 @SDL_RestoreWindow(i8*)
declare i1 @SDL_ResumeAudioDevice(i64)
declare i1 @SDL_ResumeAudioStreamDevice(i8*)
declare i1 @SDL_ResumeHaptic(i8*)
declare i8* @SDL_RotateSurface(i8*, float)
declare double @SDL_round(double)
declare float @SDL_roundf(float)
declare i1 @SDL_RumbleGamepad(i8*, i16, i16, i32)
declare i1 @SDL_RumbleGamepadTriggers(i8*, i16, i16, i32)
declare i1 @SDL_RumbleJoystick(i8*, i16, i16, i32)
declare i1 @SDL_RumbleJoystickTriggers(i8*, i16, i16, i32)
declare i1 @SDL_RunHapticEffect(i8*, i64, i32)
declare i1 @SDL_RunOnMainThread(i64, i8*, i1)
declare i1 @SDL_SaveBMP_IO(i8*, i8*, i1)
declare i1 @SDL_SaveBMP(i8*, i8*)
declare i1 @SDL_SaveFile_IO(i8*, i8*, i64, i1)
declare i1 @SDL_SaveFile(i8*, i8*, i64)
declare i1 @SDL_SavePNG_IO(i8*, i8*, i1)
declare i1 @SDL_SavePNG(i8*, i8*)
declare double @SDL_scalbn(double, i64)
declare float @SDL_scalbnf(float, i64)
declare i8* @SDL_ScaleSurface(i8*, i64, i64, i64)
declare i1 @SDL_ScreenKeyboardShown(i8*)
declare i1 @SDL_ScreenSaverEnabled()
declare i64 @SDL_SeekIO(i8*, i64, i64)
declare i1 @SDL_SendGamepadEffect(i8*, i8*, i64)
declare i1 @SDL_SendJoystickEffect(i8*, i8*, i64)
declare i1 @SDL_SendJoystickVirtualSensorData(i8*, i64, i64, i8*, i64)
declare i1 @SDL_SetAppMetadata(i8*, i8*, i8*)
declare i1 @SDL_SetAppMetadataProperty(i8*, i8*)
declare void @SDL_SetAssertionHandler(i64, i8*)
declare i64 @SDL_SetAtomicInt(i8*, i64)
declare i8* @SDL_SetAtomicPointer(i8*, i8*)
declare i32 @SDL_SetAtomicU32(i8*, i32)
declare i1 @SDL_SetAudioDeviceGain(i64, float)
declare i1 @SDL_SetAudioPostmixCallback(i64, i64, i8*)
declare i1 @SDL_SetAudioStreamFormat(i8*, i8*, i8*)
declare i1 @SDL_SetAudioStreamFrequencyRatio(i8*, float)
declare i1 @SDL_SetAudioStreamGain(i8*, float)
declare i1 @SDL_SetAudioStreamGetCallback(i8*, i64, i8*)
declare i1 @SDL_SetAudioStreamInputChannelMap(i8*, i8*, i64)
declare i1 @SDL_SetAudioStreamOutputChannelMap(i8*, i8*, i64)
declare i1 @SDL_SetAudioStreamPutCallback(i8*, i64, i8*)
declare i1 @SDL_SetBooleanProperty(i64, i8*, i1)
declare i1 @SDL_SetClipboardData(i64, i64, i8*, i8*, i64)
declare i1 @SDL_SetClipboardText(i8*)
declare i1 @SDL_SetCurrentThreadPriority(i64)
declare i1 @SDL_SetCursor(i8*)
declare i1 @SDL_SetDefaultTextureScaleMode(i8*, i64)
declare i64 @SDL_setenv_unsafe(i8*, i8*, i64)
declare i1 @SDL_SetEnvironmentVariable(i8*, i8*, i8*, i1)
declare i1 @SDL_SetError(i8*, i64, i64)
declare i1 @SDL_SetErrorV(i8*, i64, i64, i64)
declare void @SDL_SetEventEnabled(i32, i1)
declare void @SDL_SetEventFilter(i64, i8*)
declare i1 @SDL_SetFloatProperty(i64, i8*, float)
declare void @SDL_SetGamepadEventsEnabled(i1)
declare i1 @SDL_SetGamepadLED(i8*, i8, i8, i8)
declare i1 @SDL_SetGamepadMapping(i64, i8*)
declare i1 @SDL_SetGamepadPlayerIndex(i8*, i64)
declare i1 @SDL_SetGamepadSensorEnabled(i8*, i64, i1)
declare i1 @SDL_SetGPUAllowedFramesInFlight(i8*, i32)
declare void @SDL_SetGPUBlendConstants(i8*, i64)
declare void @SDL_SetGPUBufferName(i8*, i8*, i8*)
declare i1 @SDL_SetGPURenderState(i8*, i8*)
declare i1 @SDL_SetGPURenderStateFragmentUniforms(i8*, i32, i8*, i32)
declare i1 @SDL_SetGPURenderStateSamplerBindings(i8*, i64, i8*)
declare i1 @SDL_SetGPURenderStateStorageBuffers(i8*, i64, i8*)
declare i1 @SDL_SetGPURenderStateStorageTextures(i8*, i64, i8*)
declare void @SDL_SetGPUScissor(i8*, i8*)
declare void @SDL_SetGPUStencilReference(i8*, i8)
declare i1 @SDL_SetGPUSwapchainParameters(i8*, i8*, i64, i64)
declare void @SDL_SetGPUTextureName(i8*, i8*, i8*)
declare void @SDL_SetGPUViewport(i8*, i8*)
declare i1 @SDL_SetHapticAutocenter(i8*, i64)
declare i1 @SDL_SetHapticGain(i8*, i64)
declare i1 @SDL_SetHint(i8*, i8*)
declare i1 @SDL_SetHintWithPriority(i8*, i8*, i64)
declare void @SDL_SetInitialized(i8*, i1)
declare void @SDL_SetJoystickEventsEnabled(i1)
declare i1 @SDL_SetJoystickLED(i8*, i8, i8, i8)
declare i1 @SDL_SetJoystickPlayerIndex(i8*, i64)
declare i1 @SDL_SetJoystickSensorEnabled(i8*, i64, i1)
declare i1 @SDL_SetJoystickVirtualAxis(i8*, i64, i16)
declare i1 @SDL_SetJoystickVirtualBall(i8*, i64, i16, i16)
declare i1 @SDL_SetJoystickVirtualButton(i8*, i64, i1)
declare i1 @SDL_SetJoystickVirtualHat(i8*, i64, i8)
declare i1 @SDL_SetJoystickVirtualTouchpad(i8*, i64, i64, i1, float, float, float)
declare void @SDL_SetLogOutputFunction(i64, i8*)
declare void @SDL_SetLogPriorities(i64)
declare void @SDL_SetLogPriority(i64, i64)
declare i1 @SDL_SetLogPriorityPrefix(i64, i8*)
declare i1 @SDL_SetMemoryFunctions(i64, i64, i64, i64)
declare void @SDL_SetModState(i64)
declare i1 @SDL_SetNumberProperty(i64, i8*, i64)
declare i1 @SDL_SetPaletteColors(i8*, i8*, i64, i64)
declare i1 @SDL_SetPointerProperty(i64, i8*, i8*)
declare i1 @SDL_SetPointerPropertyWithCleanup(i64, i8*, i8*, i64, i8*)
declare i1 @SDL_SetPrimarySelectionText(i8*)
declare i1 @SDL_SetRelativeMouseTransform(i64, i8*)
declare i1 @SDL_SetRenderClipRect(i8*, i8*)
declare i1 @SDL_SetRenderClipRectFloat(i8*, i8*)
declare i1 @SDL_SetRenderColorScale(i8*, float)
declare i1 @SDL_SetRenderDrawBlendMode(i8*, i64)
declare i1 @SDL_SetRenderDrawColor(i8*, i8, i8, i8, i8)
declare i1 @SDL_SetRenderDrawColorFloat(i8*, float, float, float, float)
declare i1 @SDL_SetRenderHDRHeadroom(i8*, float)
declare i1 @SDL_SetRenderLogicalPresentation(i8*, i64, i64, i64)
declare i1 @SDL_SetRenderScale(i8*, float, float)
declare i1 @SDL_SetRenderTarget(i8*, i8*)
declare i1 @SDL_SetRenderTextureAddressMode(i8*, i64, i64)
declare i1 @SDL_SetRenderViewport(i8*, i8*)
declare i1 @SDL_SetRenderViewportFloat(i8*, i8*)
declare i1 @SDL_SetRenderVSync(i8*, i64)
declare i1 @SDL_SetScancodeName(i64, i8*)
declare i1 @SDL_SetSoftwareRendererSurface(i8*, i8*)
declare i1 @SDL_SetSoftwareRendererWindow(i8*, i8*)
declare i1 @SDL_SetStringProperty(i64, i8*, i8*)
declare i1 @SDL_SetSurfaceAlphaMod(i8*, i8)
declare i1 @SDL_SetSurfaceBlendMode(i8*, i64)
declare i1 @SDL_SetSurfaceClipRect(i8*, i8*)
declare i1 @SDL_SetSurfaceColorKey(i8*, i1, i32)
declare i1 @SDL_SetSurfaceColorMod(i8*, i8, i8, i8)
declare i1 @SDL_SetSurfaceColorspace(i8*, i64)
declare i1 @SDL_SetSurfacePalette(i8*, i8*)
declare i1 @SDL_SetSurfaceRLE(i8*, i1)
declare i1 @SDL_SetTextInputArea(i8*, i8*, i64)
declare i1 @SDL_SetTextureAlphaMod(i8*, i8)
declare i1 @SDL_SetTextureAlphaModFloat(i8*, float)
declare i1 @SDL_SetTextureBlendMode(i8*, i64)
declare i1 @SDL_SetTextureColorMod(i8*, i8, i8, i8)
declare i1 @SDL_SetTextureColorModFloat(i8*, float, float, float)
declare i1 @SDL_SetTexturePalette(i8*, i8*)
declare i1 @SDL_SetTextureScaleMode(i8*, i64)
declare i1 @SDL_SetTLS(i8*, i8*, i64)
declare void @SDL_SetTrayEntryCallback(i8*, i64, i8*)
declare void @SDL_SetTrayEntryChecked(i8*, i1)
declare void @SDL_SetTrayEntryEnabled(i8*, i1)
declare void @SDL_SetTrayEntryLabel(i8*, i8*)
declare void @SDL_SetTrayIcon(i8*, i8*)
declare void @SDL_SetTrayTooltip(i8*, i8*)
declare i1 @SDL_SetWindowAlwaysOnTop(i8*, i1)
declare i1 @SDL_SetWindowAspectRatio(i8*, float, float)
declare i1 @SDL_SetWindowBordered(i8*, i1)
declare i1 @SDL_SetWindowFillDocument(i8*, i1)
declare i1 @SDL_SetWindowFocusable(i8*, i1)
declare i1 @SDL_SetWindowFullscreen(i8*, i1)
declare i1 @SDL_SetWindowFullscreenMode(i8*, i8*)
declare i1 @SDL_SetWindowHitTest(i8*, i64, i8*)
declare i1 @SDL_SetWindowIcon(i8*, i8*)
declare i1 @SDL_SetWindowKeyboardGrab(i8*, i1)
declare i1 @SDL_SetWindowMaximumSize(i8*, i64, i64)
declare i1 @SDL_SetWindowMinimumSize(i8*, i64, i64)
declare i1 @SDL_SetWindowModal(i8*, i1)
declare i1 @SDL_SetWindowMouseGrab(i8*, i1)
declare i1 @SDL_SetWindowMouseRect(i8*, i8*)
declare i1 @SDL_SetWindowOpacity(i8*, float)
declare i1 @SDL_SetWindowParent(i8*, i8*)
declare i1 @SDL_SetWindowPosition(i8*, i64, i64)
declare i1 @SDL_SetWindowProgressState(i8*, i64)
declare i1 @SDL_SetWindowProgressValue(i8*, float)
declare i1 @SDL_SetWindowRelativeMouseMode(i8*, i1)
declare i1 @SDL_SetWindowResizable(i8*, i1)
declare i1 @SDL_SetWindowShape(i8*, i8*)
declare i1 @SDL_SetWindowSize(i8*, i64, i64)
declare void @SDL_SetWindowsMessageHook(i64, i8*)
declare i1 @SDL_SetWindowSurfaceVSync(i8*, i64)
declare i1 @SDL_SetWindowTitle(i8*, i8*)
declare void @SDL_SetX11EventHook(i64, i8*)
declare i1 @SDL_ShouldInit(i8*)
declare i1 @SDL_ShouldQuit(i8*)
declare i1 @SDL_ShowCursor()
declare void @SDL_ShowFileDialogWithProperties(i64, i64, i8*, i64)
declare i1 @SDL_ShowMessageBox(i8*, i8*)
declare i64 @SDL_ShowNotification(i8*, i8*, i8*, i8*, i64)
declare i64 @SDL_ShowNotificationWithProperties(i64)
declare void @SDL_ShowOpenFileDialog(i64, i8*, i8*, i8*, i64, i8*, i1)
declare void @SDL_ShowOpenFolderDialog(i64, i8*, i8*, i8*, i1)
declare void @SDL_ShowSaveFileDialog(i64, i8*, i8*, i8*, i64, i8*)
declare i1 @SDL_ShowSimpleMessageBox(i64, i8*, i8*, i8*)
declare i1 @SDL_ShowWindow(i8*)
declare i1 @SDL_ShowWindowSystemMenu(i8*, i64, i64)
declare void @SDL_SignalAsyncIOQueue(i8*)
declare void @SDL_SignalCondition(i8*)
declare void @SDL_SignalSemaphore(i8*)
declare double @SDL_sin(double)
declare float @SDL_sinf(float)
declare i64 @SDL_snprintf(i8*, i64, i8*, i64, i64)
declare double @SDL_sqrt(double)
declare float @SDL_sqrtf(float)
declare void @SDL_srand(i64)
declare i64 @SDL_sscanf(i8*, i8*, i64, i64)
declare i1 @SDL_StartTextInput(i8*)
declare i1 @SDL_StartTextInputWithProperties(i8*, i64)
declare i64 @SDL_static_cast(i64, i64)
declare i32 @SDL_StepBackUTF8(i8*, i8*)
declare i32 @SDL_StepUTF8(i8*, i8*)
declare i1 @SDL_StopHapticEffect(i8*, i64)
declare i1 @SDL_StopHapticEffects(i8*)
declare i1 @SDL_StopHapticRumble(i8*)
declare i1 @SDL_StopTextInput(i8*)
declare i1 @SDL_StorageReady(i8*)
declare i64 @SDL_strcasecmp(i8*, i8*)
declare i8* @SDL_strcasestr(i8*, i8*)
declare i8* @SDL_strchr(i8*, i64)
declare i64 @SDL_strcmp(i8*, i8*)
declare i8* @SDL_strdup(i8*)
declare i1 @SDL_StretchSurface(i8*, i8*, i8*, i8*, i64)
declare i64 @SDL_StringToGUID(i8*)
declare i64 @SDL_strlcat(i8*, i8*, i64)
declare i64 @SDL_strlcpy(i8*, i8*, i64)
declare i64 @SDL_strlen(i8*)
declare i8* @SDL_strlwr(i8*)
declare i64 @SDL_strncasecmp(i8*, i8*, i64)
declare i64 @SDL_strncmp(i8*, i8*, i64)
declare i8* @SDL_strndup(i8*, i64)
declare i64 @SDL_strnlen(i8*, i64)
declare i8* @SDL_strnstr(i8*, i8*, i64)
declare i8* @SDL_strpbrk(i8*, i8*)
declare i8* @SDL_strrchr(i8*, i64)
declare i8* @SDL_strrev(i8*)
declare i8* @SDL_strstr(i8*, i8*)
declare double @SDL_strtod(i8*, i8*)
declare i8* @SDL_strtok_r(i8*, i8*, i8*)
declare i64 @SDL_strtol(i8*, i8*, i64)
declare i64 @SDL_strtoll(i8*, i8*, i64)
declare i64 @SDL_strtoul(i8*, i8*, i64)
declare i64 @SDL_strtoull(i8*, i8*, i64)
declare i8* @SDL_strupr(i8*)
declare i1 @SDL_SubmitGPUCommandBuffer(i8*)
declare i8* @SDL_SubmitGPUCommandBufferAndAcquireFence(i8*)
declare i1 @SDL_SurfaceHasAlternateImages(i8*)
declare i1 @SDL_SurfaceHasColorKey(i8*)
declare i1 @SDL_SurfaceHasRLE(i8*)
declare i64 @SDL_swprintf(i8*, i64, i8*)
declare i1 @SDL_SyncWindow(i8*)
declare double @SDL_tan(double)
declare float @SDL_tanf(float)
declare i64 @SDL_TellIO(i8*)
declare i1 @SDL_TextInputActive(i8*)
declare i64 @SDL_TimeFromWindows(i32, i32)
declare i1 @SDL_TimeToDateTime(i64, i8*, i1)
declare void @SDL_TimeToWindows(i64, i8*, i8*)
declare i64 @SDL_tolower(i64)
declare i64 @SDL_toupper(i64)
declare double @SDL_trunc(double)
declare float @SDL_truncf(float)
declare i1 @SDL_TryLockJoysticks()
declare i1 @SDL_TryLockMutex(i8*)
declare i1 @SDL_TryLockRWLockForReading(i8*)
declare i1 @SDL_TryLockRWLockForWriting(i8*)
declare i1 @SDL_TryLockSpinlock(i8*)
declare i1 @SDL_TryWaitSemaphore(i8*)
declare i8* @SDL_UCS4ToUTF8(i32, i8*)
declare i8* @SDL_uitoa(i32, i8*, i64)
declare i8* @SDL_ulltoa(i64, i8*, i64)
declare i8* @SDL_ultoa(i64, i8*, i64)
declare void @SDL_UnbindAudioStream(i8*)
declare void @SDL_UnbindAudioStreams(i8*, i64)
declare void @SDL_UnloadObject(i8*)
declare i1 @SDL_UnlockAudioStream(i8*)
declare void @SDL_UnlockJoysticks()
declare void @SDL_UnlockMutex(i8*)
declare void @SDL_UnlockProperties(i64)
declare void @SDL_UnlockRWLock(i8*)
declare void @SDL_UnlockSpinlock(i8*)
declare void @SDL_UnlockSurface(i8*)
declare void @SDL_UnlockTexture(i8*)
declare void @SDL_UnmapGPUTransferBuffer(i8*, i8*)
declare i64 @SDL_unsetenv_unsafe(i8*)
declare i1 @SDL_UnsetEnvironmentVariable(i8*, i8*)
declare void @SDL_UpdateGamepads()
declare i1 @SDL_UpdateHapticEffect(i8*, i64, i8*)
declare void @SDL_UpdateJoysticks()
declare i1 @SDL_UpdateNVTexture(i8*, i8*, i8*, i64, i8*, i64)
declare void @SDL_UpdateSensors()
declare i1 @SDL_UpdateTexture(i8*, i8*, i8*, i64)
declare void @SDL_UpdateTrays()
declare i1 @SDL_UpdateWindowSurface(i8*)
declare i1 @SDL_UpdateWindowSurfaceRects(i8*, i8*, i64)
declare i1 @SDL_UpdateYUVTexture(i8*, i8*, i8*, i64, i8*, i64, i8*, i64)
declare void @SDL_UploadToGPUBuffer(i8*, i8*, i8*, i1)
declare void @SDL_UploadToGPUTexture(i8*, i8*, i8*, i1)
declare i64 @SDL_utf8strlcpy(i8*, i8*, i64)
declare i64 @SDL_utf8strlen(i8*)
declare i64 @SDL_utf8strnlen(i8*, i64)
declare i64 @SDL_vasprintf(i8*, i8*, i64, i64, i64)
declare i64 @SDL_vsnprintf(i8*, i64, i8*, i64, i64, i64)
declare i64 @SDL_vsscanf(i8*, i8*, i64, i64, i64)
declare i64 @SDL_vswprintf(i8*, i64, i8*, i64)
declare i1 @SDL_WaitAndAcquireGPUSwapchainTexture(i8*, i8*, i8*, i8*, i8*)
declare i1 @SDL_WaitAsyncIOResult(i8*, i8*, i32)
declare void @SDL_WaitCondition(i8*, i8*)
declare i1 @SDL_WaitConditionTimeout(i8*, i8*, i32)
declare i1 @SDL_WaitEvent(i8*)
declare i1 @SDL_WaitEventTimeout(i8*, i32)
declare i1 @SDL_WaitForGPUFences(i8*, i1, i8*, i32)
declare i1 @SDL_WaitForGPUIdle(i8*)
declare i1 @SDL_WaitForGPUSwapchain(i8*, i8*)
declare i1 @SDL_WaitProcess(i8*, i1, i8*)
declare void @SDL_WaitSemaphore(i8*)
declare i1 @SDL_WaitSemaphoreTimeout(i8*, i32)
declare void @SDL_WaitThread(i8*, i8*)
declare i1 @SDL_WarpMouseGlobal(float, float)
declare void @SDL_WarpMouseInWindow(i8*, float, float)
declare i64 @SDL_WasInit(i64)
declare i64 @SDL_wcscasecmp(i8*, i8*)
declare i64 @SDL_wcscmp(i8*, i8*)
declare i8* @SDL_wcsdup(i8*)
declare i64 @SDL_wcslcat(i8*, i8*, i64)
declare i64 @SDL_wcslcpy(i8*, i8*, i64)
declare i64 @SDL_wcslen(i8*)
declare i64 @SDL_wcsncasecmp(i8*, i8*, i64)
declare i64 @SDL_wcsncmp(i8*, i8*, i64)
declare i64 @SDL_wcsnlen(i8*, i64)
declare i8* @SDL_wcsnstr(i8*, i8*, i64)
declare i8* @SDL_wcsstr(i8*, i8*)
declare i64 @SDL_wcstol(i8*, i8*, i64)
declare i64 @SDL_wcstoll(i8*, i8*, i64)
declare i64 @SDL_wcstoul(i8*, i8*, i64)
declare i64 @SDL_wcstoull(i8*, i8*, i64)
declare i1 @SDL_WindowHasSurface(i8*)
declare i1 @SDL_WindowSupportsGPUPresentMode(i8*, i8*, i64)
declare i1 @SDL_WindowSupportsGPUSwapchainComposition(i8*, i8*, i64)
declare i1 @SDL_WriteAsyncIO(i8*, i8*, i64, i64, i8*, i8*)
declare i64 @SDL_WriteIO(i8*, i8*, i64)
declare i1 @SDL_WriteS16BE(i8*, i16)
declare i1 @SDL_WriteS16LE(i8*, i16)
declare i1 @SDL_WriteS32BE(i8*, i32)
declare i1 @SDL_WriteS32LE(i8*, i32)
declare i1 @SDL_WriteS64BE(i8*, i64)
declare i1 @SDL_WriteS64LE(i8*, i64)
declare i1 @SDL_WriteS8(i8*, i8)
declare i1 @SDL_WriteStorageFile(i8*, i8*, i8*, i64)
declare i1 @SDL_WriteSurfacePixel(i8*, i64, i64, i8, i8, i8, i8)
declare i1 @SDL_WriteSurfacePixelFloat(i8*, i64, i64, float, float, float, float)
declare i1 @SDL_WriteU16BE(i8*, i16)
declare i1 @SDL_WriteU16LE(i8*, i16)
declare i1 @SDL_WriteU32BE(i8*, i32)
declare i1 @SDL_WriteU32LE(i8*, i32)
declare i1 @SDL_WriteU64BE(i8*, i64)
declare i1 @SDL_WriteU64LE(i8*, i64)
declare i1 @SDL_WriteU8(i8*, i8)
define i1 @__hike_impl_Init(i64 %flags_arg.1) {
structured.entry.0:
  %flags.2 = alloca i64
  store i64 %flags_arg.1, i64* %flags.2
  %v3 = load i64, i64* %flags.2
  %v4 = call i1 @SDL_Init(i64 %v3)
  ret i1 %v4
structured.block.end.1:
  ret i1 false
structured.block.end.2:
  br label %structured.block.end.4
structured.after.return.3:
  br label %structured.block.end.2
structured.block.end.4:
  br label %structured.block.end.1
}

define dllexport i1 @Init(i64 %arg_0.1) {
structured.entry.0:
  %v2 = call i1 @__hike_impl_Init(i64 %arg_0.1)
  ret i1 %v2
structured.block.end.1:
  ret i1 false
structured.block.end.2:
  br label %structured.block.end.4
structured.after.return.3:
  br label %structured.block.end.2
structured.block.end.4:
  br label %structured.block.end.1
}

define i1 @__hike_impl_SetAppMetadata(i8* %name_arg.1, i8* %version_arg.3, i8* %identifier_arg.5) {
structured.entry.0:
  %name.2 = alloca i8*
  store i8* %name_arg.1, i8** %name.2
  %version.4 = alloca i8*
  store i8* %version_arg.3, i8** %version.4
  %identifier.6 = alloca i8*
  store i8* %identifier_arg.5, i8** %identifier.6
  %v7 = load i8*, i8** %name.2
  %v8 = load i8*, i8** %version.4
  %v9 = load i8*, i8** %identifier.6
  %v10 = call i1 @SDL_SetAppMetadata(i8* %v7, i8* %v8, i8* %v9)
  ret i1 %v10
structured.block.end.1:
  ret i1 false
structured.block.end.2:
  br label %structured.block.end.4
structured.after.return.3:
  br label %structured.block.end.2
structured.block.end.4:
  br label %structured.block.end.1
}

define dllexport i1 @SetAppMetadata(i8* %arg_0.1, i8* %arg_1.2, i8* %arg_2.3) {
structured.entry.0:
  %v4 = call i1 @__hike_impl_SetAppMetadata(i8* %arg_0.1, i8* %arg_1.2, i8* %arg_2.3)
  ret i1 %v4
structured.block.end.1:
  ret i1 false
structured.block.end.2:
  br label %structured.block.end.4
structured.after.return.3:
  br label %structured.block.end.2
structured.block.end.4:
  br label %structured.block.end.1
}

define i8* @__hike_impl_CreateWindow(i8* %title_arg.1, i64 %width_arg.3, i64 %height_arg.5, i64 %flags_arg.7) {
structured.entry.0:
  %title.2 = alloca i8*
  store i8* %title_arg.1, i8** %title.2
  %width.4 = alloca i64
  store i64 %width_arg.3, i64* %width.4
  %height.6 = alloca i64
  store i64 %height_arg.5, i64* %height.6
  %flags.8 = alloca i64
  store i64 %flags_arg.7, i64* %flags.8
  %v9 = load i8*, i8** %title.2
  %v10 = load i64, i64* %width.4
  %v11 = load i64, i64* %height.6
  %v12 = load i64, i64* %flags.8
  %v13 = call i8* @SDL_CreateWindow(i8* %v9, i64 %v10, i64 %v11, i64 %v12)
  ret i8* %v13
structured.block.end.1:
  ret i8* null
structured.block.end.2:
  br label %structured.block.end.4
structured.after.return.3:
  br label %structured.block.end.2
structured.block.end.4:
  br label %structured.block.end.1
}

define dllexport i8* @CreateWindow(i8* %arg_0.1, i64 %arg_1.2, i64 %arg_2.3, i64 %arg_3.4) {
structured.entry.0:
  %v5 = call i8* @__hike_impl_CreateWindow(i8* %arg_0.1, i64 %arg_1.2, i64 %arg_2.3, i64 %arg_3.4)
  ret i8* %v5
structured.block.end.1:
  ret i8* null
structured.block.end.2:
  br label %structured.block.end.4
structured.after.return.3:
  br label %structured.block.end.2
structured.block.end.4:
  br label %structured.block.end.1
}

define i64 @__hike_impl_GetWindowFlags(i8* %window_arg.1) {
structured.entry.0:
  %window.2 = alloca i8*
  store i8* %window_arg.1, i8** %window.2
  %v3 = load i8*, i8** %window.2
  %v4 = call i64 @SDL_GetWindowFlags(i8* %v3)
  ret i64 %v4
structured.block.end.1:
  ret i64 zeroinitializer
structured.block.end.2:
  br label %structured.block.end.4
structured.after.return.3:
  br label %structured.block.end.2
structured.block.end.4:
  br label %structured.block.end.1
}

define dllexport i64 @GetWindowFlags(i8* %arg_0.1) {
structured.entry.0:
  %v2 = call i64 @__hike_impl_GetWindowFlags(i8* %arg_0.1)
  ret i64 %v2
structured.block.end.1:
  ret i64 zeroinitializer
structured.block.end.2:
  br label %structured.block.end.4
structured.after.return.3:
  br label %structured.block.end.2
structured.block.end.4:
  br label %structured.block.end.1
}

define i1 @__hike_impl_SetWindowResizable(i8* %window_arg.1, i1 %resizable_arg.3) {
structured.entry.0:
  %window.2 = alloca i8*
  store i8* %window_arg.1, i8** %window.2
  %resizable.4 = alloca i1
  store i1 %resizable_arg.3, i1* %resizable.4
  %v5 = load i8*, i8** %window.2
  %v6 = load i1, i1* %resizable.4
  %v7 = call i1 @SDL_SetWindowResizable(i8* %v5, i1 %v6)
  ret i1 %v7
structured.block.end.1:
  ret i1 false
structured.block.end.2:
  br label %structured.block.end.4
structured.after.return.3:
  br label %structured.block.end.2
structured.block.end.4:
  br label %structured.block.end.1
}

define dllexport i1 @SetWindowResizable(i8* %arg_0.1, i1 %arg_1.2) {
structured.entry.0:
  %v3 = call i1 @__hike_impl_SetWindowResizable(i8* %arg_0.1, i1 %arg_1.2)
  ret i1 %v3
structured.block.end.1:
  ret i1 false
structured.block.end.2:
  br label %structured.block.end.4
structured.after.return.3:
  br label %structured.block.end.2
structured.block.end.4:
  br label %structured.block.end.1
}

define i8* @__hike_impl_CreateGPUDevice(i64 %format_arg.1, i1 %debug_arg.3, i8* %name_arg.5) {
structured.entry.0:
  %format.2 = alloca i64
  store i64 %format_arg.1, i64* %format.2
  %debug.4 = alloca i1
  store i1 %debug_arg.3, i1* %debug.4
  %name.6 = alloca i8*
  store i8* %name_arg.5, i8** %name.6
  %v7 = load i64, i64* %format.2
  %v8 = load i1, i1* %debug.4
  %v9 = load i8*, i8** %name.6
  %v10 = call i8* @SDL_CreateGPUDevice(i64 %v7, i1 %v8, i8* %v9)
  ret i8* %v10
structured.block.end.1:
  ret i8* null
structured.block.end.2:
  br label %structured.block.end.4
structured.after.return.3:
  br label %structured.block.end.2
structured.block.end.4:
  br label %structured.block.end.1
}

define dllexport i8* @CreateGPUDevice(i64 %arg_0.1, i1 %arg_1.2, i8* %arg_2.3) {
structured.entry.0:
  %v4 = call i8* @__hike_impl_CreateGPUDevice(i64 %arg_0.1, i1 %arg_1.2, i8* %arg_2.3)
  ret i8* %v4
structured.block.end.1:
  ret i8* null
structured.block.end.2:
  br label %structured.block.end.4
structured.after.return.3:
  br label %structured.block.end.2
structured.block.end.4:
  br label %structured.block.end.1
}

define void @__hike_impl_DestroyGPUDevice(i8* %device_arg.1) {
structured.entry.0:
  %device.2 = alloca i8*
  store i8* %device_arg.1, i8** %device.2
  %v3 = load i8*, i8** %device.2
  call void @SDL_DestroyGPUDevice(i8* %v3)
  ret void
structured.block.end.1:
  ret void
structured.block.end.2:
  br label %structured.block.end.4
structured.after.return.3:
  br label %structured.block.end.2
structured.block.end.4:
  br label %structured.block.end.1
}

define dllexport void @DestroyGPUDevice(i8* %arg_0.1) {
structured.entry.0:
  call void @__hike_impl_DestroyGPUDevice(i8* %arg_0.1)
  ret void
structured.block.end.1:
  ret void
structured.block.end.2:
  br label %structured.block.end.4
structured.after.return.3:
  br label %structured.block.end.2
structured.block.end.4:
  br label %structured.block.end.1
}

define i1 @__hike_impl_ClaimWindowForGPUDevice(i8* %device_arg.1, i8* %window_arg.3) {
structured.entry.0:
  %device.2 = alloca i8*
  store i8* %device_arg.1, i8** %device.2
  %window.4 = alloca i8*
  store i8* %window_arg.3, i8** %window.4
  %v5 = load i8*, i8** %device.2
  %v6 = load i8*, i8** %window.4
  %v7 = call i1 @SDL_ClaimWindowForGPUDevice(i8* %v5, i8* %v6)
  ret i1 %v7
structured.block.end.1:
  ret i1 false
structured.block.end.2:
  br label %structured.block.end.4
structured.after.return.3:
  br label %structured.block.end.2
structured.block.end.4:
  br label %structured.block.end.1
}

define dllexport i1 @ClaimWindowForGPUDevice(i8* %arg_0.1, i8* %arg_1.2) {
structured.entry.0:
  %v3 = call i1 @__hike_impl_ClaimWindowForGPUDevice(i8* %arg_0.1, i8* %arg_1.2)
  ret i1 %v3
structured.block.end.1:
  ret i1 false
structured.block.end.2:
  br label %structured.block.end.4
structured.after.return.3:
  br label %structured.block.end.2
structured.block.end.4:
  br label %structured.block.end.1
}

define void @__hike_impl_ReleaseWindowFromGPUDevice(i8* %device_arg.1, i8* %window_arg.3) {
structured.entry.0:
  %device.2 = alloca i8*
  store i8* %device_arg.1, i8** %device.2
  %window.4 = alloca i8*
  store i8* %window_arg.3, i8** %window.4
  %v5 = load i8*, i8** %device.2
  %v6 = load i8*, i8** %window.4
  call void @SDL_ReleaseWindowFromGPUDevice(i8* %v5, i8* %v6)
  ret void
structured.block.end.1:
  ret void
structured.block.end.2:
  br label %structured.block.end.4
structured.after.return.3:
  br label %structured.block.end.2
structured.block.end.4:
  br label %structured.block.end.1
}

define dllexport void @ReleaseWindowFromGPUDevice(i8* %arg_0.1, i8* %arg_1.2) {
structured.entry.0:
  call void @__hike_impl_ReleaseWindowFromGPUDevice(i8* %arg_0.1, i8* %arg_1.2)
  ret void
structured.block.end.1:
  ret void
structured.block.end.2:
  br label %structured.block.end.4
structured.after.return.3:
  br label %structured.block.end.2
structured.block.end.4:
  br label %structured.block.end.1
}

define i8* @__hike_impl_AcquireGPUCommandBuffer(i8* %device_arg.1) {
structured.entry.0:
  %device.2 = alloca i8*
  store i8* %device_arg.1, i8** %device.2
  %v3 = load i8*, i8** %device.2
  %v4 = call i8* @SDL_AcquireGPUCommandBuffer(i8* %v3)
  ret i8* %v4
structured.block.end.1:
  ret i8* null
structured.block.end.2:
  br label %structured.block.end.4
structured.after.return.3:
  br label %structured.block.end.2
structured.block.end.4:
  br label %structured.block.end.1
}

define dllexport i8* @AcquireGPUCommandBuffer(i8* %arg_0.1) {
structured.entry.0:
  %v2 = call i8* @__hike_impl_AcquireGPUCommandBuffer(i8* %arg_0.1)
  ret i8* %v2
structured.block.end.1:
  ret i8* null
structured.block.end.2:
  br label %structured.block.end.4
structured.after.return.3:
  br label %structured.block.end.2
structured.block.end.4:
  br label %structured.block.end.1
}

define i1 @__hike_impl_AcquireGPUSwapchainTexture(i8* %commandBuffer_arg.1, i8* %window_arg.3, i8* %texture_arg.5, i8* %width_arg.7, i8* %height_arg.9) {
structured.entry.0:
  %commandBuffer.2 = alloca i8*
  store i8* %commandBuffer_arg.1, i8** %commandBuffer.2
  %window.4 = alloca i8*
  store i8* %window_arg.3, i8** %window.4
  %texture.6 = alloca i8*
  store i8* %texture_arg.5, i8** %texture.6
  %width.8 = alloca i8*
  store i8* %width_arg.7, i8** %width.8
  %height.10 = alloca i8*
  store i8* %height_arg.9, i8** %height.10
  %v11 = load i8*, i8** %commandBuffer.2
  %v12 = load i8*, i8** %window.4
  %v13 = load i8*, i8** %texture.6
  %v14 = load i8*, i8** %width.8
  %v15 = load i8*, i8** %height.10
  %v16 = call i1 @SDL_AcquireGPUSwapchainTexture(i8* %v11, i8* %v12, i8* %v13, i8* %v14, i8* %v15)
  ret i1 %v16
structured.block.end.1:
  ret i1 false
structured.block.end.2:
  br label %structured.block.end.4
structured.after.return.3:
  br label %structured.block.end.2
structured.block.end.4:
  br label %structured.block.end.1
}

define dllexport i1 @AcquireGPUSwapchainTexture(i8* %arg_0.1, i8* %arg_1.2, i8* %arg_2.3, i8* %arg_3.4, i8* %arg_4.5) {
structured.entry.0:
  %v6 = call i1 @__hike_impl_AcquireGPUSwapchainTexture(i8* %arg_0.1, i8* %arg_1.2, i8* %arg_2.3, i8* %arg_3.4, i8* %arg_4.5)
  ret i1 %v6
structured.block.end.1:
  ret i1 false
structured.block.end.2:
  br label %structured.block.end.4
structured.after.return.3:
  br label %structured.block.end.2
structured.block.end.4:
  br label %structured.block.end.1
}

define i1 @__hike_impl_SubmitGPUCommandBuffer(i8* %commandBuffer_arg.1) {
structured.entry.0:
  %commandBuffer.2 = alloca i8*
  store i8* %commandBuffer_arg.1, i8** %commandBuffer.2
  %v3 = load i8*, i8** %commandBuffer.2
  %v4 = call i1 @SDL_SubmitGPUCommandBuffer(i8* %v3)
  ret i1 %v4
structured.block.end.1:
  ret i1 false
structured.block.end.2:
  br label %structured.block.end.4
structured.after.return.3:
  br label %structured.block.end.2
structured.block.end.4:
  br label %structured.block.end.1
}

define dllexport i1 @SubmitGPUCommandBuffer(i8* %arg_0.1) {
structured.entry.0:
  %v2 = call i1 @__hike_impl_SubmitGPUCommandBuffer(i8* %arg_0.1)
  ret i1 %v2
structured.block.end.1:
  ret i1 false
structured.block.end.2:
  br label %structured.block.end.4
structured.after.return.3:
  br label %structured.block.end.2
structured.block.end.4:
  br label %structured.block.end.1
}

define i1 @__hike_impl_CancelGPUCommandBuffer(i8* %commandBuffer_arg.1) {
structured.entry.0:
  %commandBuffer.2 = alloca i8*
  store i8* %commandBuffer_arg.1, i8** %commandBuffer.2
  %v3 = load i8*, i8** %commandBuffer.2
  %v4 = call i1 @SDL_CancelGPUCommandBuffer(i8* %v3)
  ret i1 %v4
structured.block.end.1:
  ret i1 false
structured.block.end.2:
  br label %structured.block.end.4
structured.after.return.3:
  br label %structured.block.end.2
structured.block.end.4:
  br label %structured.block.end.1
}

define dllexport i1 @CancelGPUCommandBuffer(i8* %arg_0.1) {
structured.entry.0:
  %v2 = call i1 @__hike_impl_CancelGPUCommandBuffer(i8* %arg_0.1)
  ret i1 %v2
structured.block.end.1:
  ret i1 false
structured.block.end.2:
  br label %structured.block.end.4
structured.after.return.3:
  br label %structured.block.end.2
structured.block.end.4:
  br label %structured.block.end.1
}

define i1 @__hike_impl_SetGPUSwapchainParameters(i8* %device_arg.1, i8* %window_arg.3, i64 %composition_arg.5, i64 %presentMode_arg.7) {
structured.entry.0:
  %device.2 = alloca i8*
  store i8* %device_arg.1, i8** %device.2
  %window.4 = alloca i8*
  store i8* %window_arg.3, i8** %window.4
  %composition.6 = alloca i64
  store i64 %composition_arg.5, i64* %composition.6
  %presentMode.8 = alloca i64
  store i64 %presentMode_arg.7, i64* %presentMode.8
  %v9 = load i8*, i8** %device.2
  %v10 = load i8*, i8** %window.4
  %v11 = load i64, i64* %composition.6
  %v12 = load i64, i64* %presentMode.8
  %v13 = call i1 @SDL_SetGPUSwapchainParameters(i8* %v9, i8* %v10, i64 %v11, i64 %v12)
  ret i1 %v13
structured.block.end.1:
  ret i1 false
structured.block.end.2:
  br label %structured.block.end.4
structured.after.return.3:
  br label %structured.block.end.2
structured.block.end.4:
  br label %structured.block.end.1
}

define dllexport i1 @SetGPUSwapchainParameters(i8* %arg_0.1, i8* %arg_1.2, i64 %arg_2.3, i64 %arg_3.4) {
structured.entry.0:
  %v5 = call i1 @__hike_impl_SetGPUSwapchainParameters(i8* %arg_0.1, i8* %arg_1.2, i64 %arg_2.3, i64 %arg_3.4)
  ret i1 %v5
structured.block.end.1:
  ret i1 false
structured.block.end.2:
  br label %structured.block.end.4
structured.after.return.3:
  br label %structured.block.end.2
structured.block.end.4:
  br label %structured.block.end.1
}

define i8* @__hike_impl_GetGPUDeviceDriver(i8* %device_arg.1) {
structured.entry.0:
  %device.2 = alloca i8*
  store i8* %device_arg.1, i8** %device.2
  %v3 = load i8*, i8** %device.2
  %v4 = call i8* @SDL_GetGPUDeviceDriver(i8* %v3)
  ret i8* %v4
structured.block.end.1:
  ret i8* zeroinitializer
structured.block.end.2:
  br label %structured.block.end.4
structured.after.return.3:
  br label %structured.block.end.2
structured.block.end.4:
  br label %structured.block.end.1
}

define dllexport i8* @GetGPUDeviceDriver(i8* %arg_0.1) {
structured.entry.0:
  %v2 = call i8* @__hike_impl_GetGPUDeviceDriver(i8* %arg_0.1)
  ret i8* %v2
structured.block.end.1:
  ret i8* zeroinitializer
structured.block.end.2:
  br label %structured.block.end.4
structured.after.return.3:
  br label %structured.block.end.2
structured.block.end.4:
  br label %structured.block.end.1
}

define i64 @__hike_impl_GetGPUShaderFormats(i8* %device_arg.1) {
structured.entry.0:
  %device.2 = alloca i8*
  store i8* %device_arg.1, i8** %device.2
  %v3 = load i8*, i8** %device.2
  %v4 = call i64 @SDL_GetGPUShaderFormats(i8* %v3)
  ret i64 %v4
structured.block.end.1:
  ret i64 zeroinitializer
structured.block.end.2:
  br label %structured.block.end.4
structured.after.return.3:
  br label %structured.block.end.2
structured.block.end.4:
  br label %structured.block.end.1
}

define dllexport i64 @GetGPUShaderFormats(i8* %arg_0.1) {
structured.entry.0:
  %v2 = call i64 @__hike_impl_GetGPUShaderFormats(i8* %arg_0.1)
  ret i64 %v2
structured.block.end.1:
  ret i64 zeroinitializer
structured.block.end.2:
  br label %structured.block.end.4
structured.after.return.3:
  br label %structured.block.end.2
structured.block.end.4:
  br label %structured.block.end.1
}

define i64 @__hike_impl_GetGPUSwapchainTextureFormat(i8* %device_arg.1, i8* %window_arg.3) {
structured.entry.0:
  %device.2 = alloca i8*
  store i8* %device_arg.1, i8** %device.2
  %window.4 = alloca i8*
  store i8* %window_arg.3, i8** %window.4
  %v5 = load i8*, i8** %device.2
  %v6 = load i8*, i8** %window.4
  %v7 = call i64 @SDL_GetGPUSwapchainTextureFormat(i8* %v5, i8* %v6)
  ret i64 %v7
structured.block.end.1:
  ret i64 zeroinitializer
structured.block.end.2:
  br label %structured.block.end.4
structured.after.return.3:
  br label %structured.block.end.2
structured.block.end.4:
  br label %structured.block.end.1
}

define dllexport i64 @GetGPUSwapchainTextureFormat(i8* %arg_0.1, i8* %arg_1.2) {
structured.entry.0:
  %v3 = call i64 @__hike_impl_GetGPUSwapchainTextureFormat(i8* %arg_0.1, i8* %arg_1.2)
  ret i64 %v3
structured.block.end.1:
  ret i64 zeroinitializer
structured.block.end.2:
  br label %structured.block.end.4
structured.after.return.3:
  br label %structured.block.end.2
structured.block.end.4:
  br label %structured.block.end.1
}

define i1 @__hike_impl_WaitForGPUSwapchain(i8* %device_arg.1, i8* %window_arg.3) {
structured.entry.0:
  %device.2 = alloca i8*
  store i8* %device_arg.1, i8** %device.2
  %window.4 = alloca i8*
  store i8* %window_arg.3, i8** %window.4
  %v5 = load i8*, i8** %device.2
  %v6 = load i8*, i8** %window.4
  %v7 = call i1 @SDL_WaitForGPUSwapchain(i8* %v5, i8* %v6)
  ret i1 %v7
structured.block.end.1:
  ret i1 false
structured.block.end.2:
  br label %structured.block.end.4
structured.after.return.3:
  br label %structured.block.end.2
structured.block.end.4:
  br label %structured.block.end.1
}

define dllexport i1 @WaitForGPUSwapchain(i8* %arg_0.1, i8* %arg_1.2) {
structured.entry.0:
  %v3 = call i1 @__hike_impl_WaitForGPUSwapchain(i8* %arg_0.1, i8* %arg_1.2)
  ret i1 %v3
structured.block.end.1:
  ret i1 false
structured.block.end.2:
  br label %structured.block.end.4
structured.after.return.3:
  br label %structured.block.end.2
structured.block.end.4:
  br label %structured.block.end.1
}

define i1 @__hike_impl_WaitForGPUIdle(i8* %device_arg.1) {
structured.entry.0:
  %device.2 = alloca i8*
  store i8* %device_arg.1, i8** %device.2
  %v3 = load i8*, i8** %device.2
  %v4 = call i1 @SDL_WaitForGPUIdle(i8* %v3)
  ret i1 %v4
structured.block.end.1:
  ret i1 false
structured.block.end.2:
  br label %structured.block.end.4
structured.after.return.3:
  br label %structured.block.end.2
structured.block.end.4:
  br label %structured.block.end.1
}

define dllexport i1 @WaitForGPUIdle(i8* %arg_0.1) {
structured.entry.0:
  %v2 = call i1 @__hike_impl_WaitForGPUIdle(i8* %arg_0.1)
  ret i1 %v2
structured.block.end.1:
  ret i1 false
structured.block.end.2:
  br label %structured.block.end.4
structured.after.return.3:
  br label %structured.block.end.2
structured.block.end.4:
  br label %structured.block.end.1
}

define i8* @__hike_impl_CreateRenderer(i8* %window_arg.1, i8* %name_arg.3) {
structured.entry.0:
  %window.2 = alloca i8*
  store i8* %window_arg.1, i8** %window.2
  %name.4 = alloca i8*
  store i8* %name_arg.3, i8** %name.4
  %v5 = load i8*, i8** %window.2
  %v6 = load i8*, i8** %name.4
  %v7 = call i8* @SDL_CreateRenderer(i8* %v5, i8* %v6)
  ret i8* %v7
structured.block.end.1:
  ret i8* null
structured.block.end.2:
  br label %structured.block.end.4
structured.after.return.3:
  br label %structured.block.end.2
structured.block.end.4:
  br label %structured.block.end.1
}

define dllexport i8* @CreateRenderer(i8* %arg_0.1, i8* %arg_1.2) {
structured.entry.0:
  %v3 = call i8* @__hike_impl_CreateRenderer(i8* %arg_0.1, i8* %arg_1.2)
  ret i8* %v3
structured.block.end.1:
  ret i8* null
structured.block.end.2:
  br label %structured.block.end.4
structured.after.return.3:
  br label %structured.block.end.2
structured.block.end.4:
  br label %structured.block.end.1
}

define i1 @__hike_impl_RenderGeometry(i8* %renderer_arg.1, i8* %texture_arg.3, i8* %vertices_arg.5, i64 %vertexCount_arg.7, i8* %indices_arg.9, i64 %indexCount_arg.11) {
structured.entry.0:
  %renderer.2 = alloca i8*
  store i8* %renderer_arg.1, i8** %renderer.2
  %texture.4 = alloca i8*
  store i8* %texture_arg.3, i8** %texture.4
  %vertices.6 = alloca i8*
  store i8* %vertices_arg.5, i8** %vertices.6
  %vertexCount.8 = alloca i64
  store i64 %vertexCount_arg.7, i64* %vertexCount.8
  %indices.10 = alloca i8*
  store i8* %indices_arg.9, i8** %indices.10
  %indexCount.12 = alloca i64
  store i64 %indexCount_arg.11, i64* %indexCount.12
  %v13 = load i8*, i8** %renderer.2
  %v14 = load i8*, i8** %texture.4
  %v15 = load i8*, i8** %vertices.6
  %v16 = load i64, i64* %vertexCount.8
  %v17 = load i8*, i8** %indices.10
  %v18 = load i64, i64* %indexCount.12
  %v19 = call i1 @SDL_RenderGeometry(i8* %v13, i8* %v14, i8* %v15, i64 %v16, i8* %v17, i64 %v18)
  ret i1 %v19
structured.block.end.1:
  ret i1 false
structured.block.end.2:
  br label %structured.block.end.4
structured.after.return.3:
  br label %structured.block.end.2
structured.block.end.4:
  br label %structured.block.end.1
}

define dllexport i1 @RenderGeometry(i8* %arg_0.1, i8* %arg_1.2, i8* %arg_2.3, i64 %arg_3.4, i8* %arg_4.5, i64 %arg_5.6) {
structured.entry.0:
  %v7 = call i1 @__hike_impl_RenderGeometry(i8* %arg_0.1, i8* %arg_1.2, i8* %arg_2.3, i64 %arg_3.4, i8* %arg_4.5, i64 %arg_5.6)
  ret i1 %v7
structured.block.end.1:
  ret i1 false
structured.block.end.2:
  br label %structured.block.end.4
structured.after.return.3:
  br label %structured.block.end.2
structured.block.end.4:
  br label %structured.block.end.1
}

define i1 @__hike_impl_SetRenderLogicalPresentation(i8* %renderer_arg.1, i64 %width_arg.3, i64 %height_arg.5, i64 %mode_arg.7) {
structured.entry.0:
  %renderer.2 = alloca i8*
  store i8* %renderer_arg.1, i8** %renderer.2
  %width.4 = alloca i64
  store i64 %width_arg.3, i64* %width.4
  %height.6 = alloca i64
  store i64 %height_arg.5, i64* %height.6
  %mode.8 = alloca i64
  store i64 %mode_arg.7, i64* %mode.8
  %v9 = load i8*, i8** %renderer.2
  %v10 = load i64, i64* %width.4
  %v11 = load i64, i64* %height.6
  %v12 = load i64, i64* %mode.8
  %v13 = call i1 @SDL_SetRenderLogicalPresentation(i8* %v9, i64 %v10, i64 %v11, i64 %v12)
  ret i1 %v13
structured.block.end.1:
  ret i1 false
structured.block.end.2:
  br label %structured.block.end.4
structured.after.return.3:
  br label %structured.block.end.2
structured.block.end.4:
  br label %structured.block.end.1
}

define dllexport i1 @SetRenderLogicalPresentation(i8* %arg_0.1, i64 %arg_1.2, i64 %arg_2.3, i64 %arg_3.4) {
structured.entry.0:
  %v5 = call i1 @__hike_impl_SetRenderLogicalPresentation(i8* %arg_0.1, i64 %arg_1.2, i64 %arg_2.3, i64 %arg_3.4)
  ret i1 %v5
structured.block.end.1:
  ret i1 false
structured.block.end.2:
  br label %structured.block.end.4
structured.after.return.3:
  br label %structured.block.end.2
structured.block.end.4:
  br label %structured.block.end.1
}

define i1 @__hike_impl_SetRenderDrawColor(i8* %renderer_arg.1, i8 %red_arg.3, i8 %green_arg.5, i8 %blue_arg.7, i8 %alpha_arg.9) {
structured.entry.0:
  %renderer.2 = alloca i8*
  store i8* %renderer_arg.1, i8** %renderer.2
  %red.4 = alloca i8
  store i8 %red_arg.3, i8* %red.4
  %green.6 = alloca i8
  store i8 %green_arg.5, i8* %green.6
  %blue.8 = alloca i8
  store i8 %blue_arg.7, i8* %blue.8
  %alpha.10 = alloca i8
  store i8 %alpha_arg.9, i8* %alpha.10
  %v11 = load i8*, i8** %renderer.2
  %v12 = load i8, i8* %red.4
  %v13 = load i8, i8* %green.6
  %v14 = load i8, i8* %blue.8
  %v15 = load i8, i8* %alpha.10
  %v16 = call i1 @SDL_SetRenderDrawColor(i8* %v11, i8 %v12, i8 %v13, i8 %v14, i8 %v15)
  ret i1 %v16
structured.block.end.1:
  ret i1 false
structured.block.end.2:
  br label %structured.block.end.4
structured.after.return.3:
  br label %structured.block.end.2
structured.block.end.4:
  br label %structured.block.end.1
}

define dllexport i1 @SetRenderDrawColor(i8* %arg_0.1, i8 %arg_1.2, i8 %arg_2.3, i8 %arg_3.4, i8 %arg_4.5) {
structured.entry.0:
  %v6 = call i1 @__hike_impl_SetRenderDrawColor(i8* %arg_0.1, i8 %arg_1.2, i8 %arg_2.3, i8 %arg_3.4, i8 %arg_4.5)
  ret i1 %v6
structured.block.end.1:
  ret i1 false
structured.block.end.2:
  br label %structured.block.end.4
structured.after.return.3:
  br label %structured.block.end.2
structured.block.end.4:
  br label %structured.block.end.1
}

define i1 @__hike_impl_RenderClear(i8* %renderer_arg.1) {
structured.entry.0:
  %renderer.2 = alloca i8*
  store i8* %renderer_arg.1, i8** %renderer.2
  %v3 = load i8*, i8** %renderer.2
  %v4 = call i1 @SDL_RenderClear(i8* %v3)
  ret i1 %v4
structured.block.end.1:
  ret i1 false
structured.block.end.2:
  br label %structured.block.end.4
structured.after.return.3:
  br label %structured.block.end.2
structured.block.end.4:
  br label %structured.block.end.1
}

define dllexport i1 @RenderClear(i8* %arg_0.1) {
structured.entry.0:
  %v2 = call i1 @__hike_impl_RenderClear(i8* %arg_0.1)
  ret i1 %v2
structured.block.end.1:
  ret i1 false
structured.block.end.2:
  br label %structured.block.end.4
structured.after.return.3:
  br label %structured.block.end.2
structured.block.end.4:
  br label %structured.block.end.1
}

define i1 @__hike_impl_RenderLine(i8* %renderer_arg.1, float %x1_arg.3, float %y1_arg.5, float %x2_arg.7, float %y2_arg.9) {
structured.entry.0:
  %renderer.2 = alloca i8*
  store i8* %renderer_arg.1, i8** %renderer.2
  %x1.4 = alloca float
  store float %x1_arg.3, float* %x1.4
  %y1.6 = alloca float
  store float %y1_arg.5, float* %y1.6
  %x2.8 = alloca float
  store float %x2_arg.7, float* %x2.8
  %y2.10 = alloca float
  store float %y2_arg.9, float* %y2.10
  %v11 = load i8*, i8** %renderer.2
  %v12 = load float, float* %x1.4
  %v13 = load float, float* %y1.6
  %v14 = load float, float* %x2.8
  %v15 = load float, float* %y2.10
  %v16 = call i1 @SDL_RenderLine(i8* %v11, float %v12, float %v13, float %v14, float %v15)
  ret i1 %v16
structured.block.end.1:
  ret i1 false
structured.block.end.2:
  br label %structured.block.end.4
structured.after.return.3:
  br label %structured.block.end.2
structured.block.end.4:
  br label %structured.block.end.1
}

define dllexport i1 @RenderLine(i8* %arg_0.1, float %arg_1.2, float %arg_2.3, float %arg_3.4, float %arg_4.5) {
structured.entry.0:
  %v6 = call i1 @__hike_impl_RenderLine(i8* %arg_0.1, float %arg_1.2, float %arg_2.3, float %arg_3.4, float %arg_4.5)
  ret i1 %v6
structured.block.end.1:
  ret i1 false
structured.block.end.2:
  br label %structured.block.end.4
structured.after.return.3:
  br label %structured.block.end.2
structured.block.end.4:
  br label %structured.block.end.1
}

define i1 @__hike_impl_RenderLines(i8* %renderer_arg.1, i8* %points_arg.3, i64 %count_arg.5) {
structured.entry.0:
  %renderer.2 = alloca i8*
  store i8* %renderer_arg.1, i8** %renderer.2
  %points.4 = alloca i8*
  store i8* %points_arg.3, i8** %points.4
  %count.6 = alloca i64
  store i64 %count_arg.5, i64* %count.6
  %v7 = load i8*, i8** %renderer.2
  %v8 = load i8*, i8** %points.4
  %v9 = load i64, i64* %count.6
  %v10 = call i1 @SDL_RenderLines(i8* %v7, i8* %v8, i64 %v9)
  ret i1 %v10
structured.block.end.1:
  ret i1 false
structured.block.end.2:
  br label %structured.block.end.4
structured.after.return.3:
  br label %structured.block.end.2
structured.block.end.4:
  br label %structured.block.end.1
}

define dllexport i1 @RenderLines(i8* %arg_0.1, i8* %arg_1.2, i64 %arg_2.3) {
structured.entry.0:
  %v4 = call i1 @__hike_impl_RenderLines(i8* %arg_0.1, i8* %arg_1.2, i64 %arg_2.3)
  ret i1 %v4
structured.block.end.1:
  ret i1 false
structured.block.end.2:
  br label %structured.block.end.4
structured.after.return.3:
  br label %structured.block.end.2
structured.block.end.4:
  br label %structured.block.end.1
}

define i1 @__hike_impl_RenderPresent(i8* %renderer_arg.1) {
structured.entry.0:
  %renderer.2 = alloca i8*
  store i8* %renderer_arg.1, i8** %renderer.2
  %v3 = load i8*, i8** %renderer.2
  %v4 = call i1 @SDL_RenderPresent(i8* %v3)
  ret i1 %v4
structured.block.end.1:
  ret i1 false
structured.block.end.2:
  br label %structured.block.end.4
structured.after.return.3:
  br label %structured.block.end.2
structured.block.end.4:
  br label %structured.block.end.1
}

define dllexport i1 @RenderPresent(i8* %arg_0.1) {
structured.entry.0:
  %v2 = call i1 @__hike_impl_RenderPresent(i8* %arg_0.1)
  ret i1 %v2
structured.block.end.1:
  ret i1 false
structured.block.end.2:
  br label %structured.block.end.4
structured.after.return.3:
  br label %structured.block.end.2
structured.block.end.4:
  br label %structured.block.end.1
}

define i1 @__hike_impl_PollEvent(i8* %event_arg.1) {
structured.entry.0:
  %event.2 = alloca i8*
  store i8* %event_arg.1, i8** %event.2
  %v3 = load i8*, i8** %event.2
  %v4 = call i1 @SDL_PollEvent(i8* %v3)
  ret i1 %v4
structured.block.end.1:
  ret i1 false
structured.block.end.2:
  br label %structured.block.end.4
structured.after.return.3:
  br label %structured.block.end.2
structured.block.end.4:
  br label %structured.block.end.1
}

define dllexport i1 @PollEvent(i8* %arg_0.1) {
structured.entry.0:
  %v2 = call i1 @__hike_impl_PollEvent(i8* %arg_0.1)
  ret i1 %v2
structured.block.end.1:
  ret i1 false
structured.block.end.2:
  br label %structured.block.end.4
structured.after.return.3:
  br label %structured.block.end.2
structured.block.end.4:
  br label %structured.block.end.1
}

define i32 @__hike_impl_Rand(i32 %max_arg.1) {
structured.entry.0:
  %max.2 = alloca i32
  store i32 %max_arg.1, i32* %max.2
  %v3 = load i32, i32* %max.2
  %v4 = call i32 @SDL_rand(i32 %v3)
  ret i32 %v4
structured.block.end.1:
  ret i32 zeroinitializer
structured.block.end.2:
  br label %structured.block.end.4
structured.after.return.3:
  br label %structured.block.end.2
structured.block.end.4:
  br label %structured.block.end.1
}

define dllexport i32 @Rand(i32 %arg_0.1) {
structured.entry.0:
  %v2 = call i32 @__hike_impl_Rand(i32 %arg_0.1)
  ret i32 %v2
structured.block.end.1:
  ret i32 zeroinitializer
structured.block.end.2:
  br label %structured.block.end.4
structured.after.return.3:
  br label %structured.block.end.2
structured.block.end.4:
  br label %structured.block.end.1
}

define float @__hike_impl_Cos(float %value_arg.1) {
structured.entry.0:
  %value.2 = alloca float
  store float %value_arg.1, float* %value.2
  %v3 = load float, float* %value.2
  %v4 = call float @SDL_cosf(float %v3)
  ret float %v4
structured.block.end.1:
  ret float 0.0
structured.block.end.2:
  br label %structured.block.end.4
structured.after.return.3:
  br label %structured.block.end.2
structured.block.end.4:
  br label %structured.block.end.1
}

define dllexport float @Cos(float %arg_0.1) {
structured.entry.0:
  %v2 = call float @__hike_impl_Cos(float %arg_0.1)
  ret float %v2
structured.block.end.1:
  ret float 0.0
structured.block.end.2:
  br label %structured.block.end.4
structured.after.return.3:
  br label %structured.block.end.2
structured.block.end.4:
  br label %structured.block.end.1
}

define float @__hike_impl_Sin(float %value_arg.1) {
structured.entry.0:
  %value.2 = alloca float
  store float %value_arg.1, float* %value.2
  %v3 = load float, float* %value.2
  %v4 = call float @SDL_sinf(float %v3)
  ret float %v4
structured.block.end.1:
  ret float 0.0
structured.block.end.2:
  br label %structured.block.end.4
structured.after.return.3:
  br label %structured.block.end.2
structured.block.end.4:
  br label %structured.block.end.1
}

define dllexport float @Sin(float %arg_0.1) {
structured.entry.0:
  %v2 = call float @__hike_impl_Sin(float %arg_0.1)
  ret float %v2
structured.block.end.1:
  ret float 0.0
structured.block.end.2:
  br label %structured.block.end.4
structured.after.return.3:
  br label %structured.block.end.2
structured.block.end.4:
  br label %structured.block.end.1
}

define i8* @__hike_impl_GetError() {
structured.entry.0:
  %v1 = call i8* @SDL_GetError()
  ret i8* %v1
structured.block.end.1:
  ret i8* zeroinitializer
structured.block.end.2:
  br label %structured.block.end.4
structured.after.return.3:
  br label %structured.block.end.2
structured.block.end.4:
  br label %structured.block.end.1
}

define dllexport i8* @GetError() {
structured.entry.0:
  %v1 = call i8* @__hike_impl_GetError()
  ret i8* %v1
structured.block.end.1:
  ret i8* zeroinitializer
structured.block.end.2:
  br label %structured.block.end.4
structured.after.return.3:
  br label %structured.block.end.2
structured.block.end.4:
  br label %structured.block.end.1
}

define void @__hike_impl_DestroyRenderer(i8* %renderer_arg.1) {
structured.entry.0:
  %renderer.2 = alloca i8*
  store i8* %renderer_arg.1, i8** %renderer.2
  %v3 = load i8*, i8** %renderer.2
  call void @SDL_DestroyRenderer(i8* %v3)
  ret void
structured.block.end.1:
  ret void
structured.block.end.2:
  br label %structured.block.end.4
structured.after.return.3:
  br label %structured.block.end.2
structured.block.end.4:
  br label %structured.block.end.1
}

define dllexport void @DestroyRenderer(i8* %arg_0.1) {
structured.entry.0:
  call void @__hike_impl_DestroyRenderer(i8* %arg_0.1)
  ret void
structured.block.end.1:
  ret void
structured.block.end.2:
  br label %structured.block.end.4
structured.after.return.3:
  br label %structured.block.end.2
structured.block.end.4:
  br label %structured.block.end.1
}

define void @__hike_impl_DestroyWindow(i8* %window_arg.1) {
structured.entry.0:
  %window.2 = alloca i8*
  store i8* %window_arg.1, i8** %window.2
  %v3 = load i8*, i8** %window.2
  call void @SDL_DestroyWindow(i8* %v3)
  ret void
structured.block.end.1:
  ret void
structured.block.end.2:
  br label %structured.block.end.4
structured.after.return.3:
  br label %structured.block.end.2
structured.block.end.4:
  br label %structured.block.end.1
}

define dllexport void @DestroyWindow(i8* %arg_0.1) {
structured.entry.0:
  call void @__hike_impl_DestroyWindow(i8* %arg_0.1)
  ret void
structured.block.end.1:
  ret void
structured.block.end.2:
  br label %structured.block.end.4
structured.after.return.3:
  br label %structured.block.end.2
structured.block.end.4:
  br label %structured.block.end.1
}

define void @__hike_impl_Quit() {
structured.entry.0:
  call void @SDL_Quit()
  ret void
structured.block.end.1:
  ret void
structured.block.end.2:
  br label %structured.block.end.4
structured.after.return.3:
  br label %structured.block.end.2
structured.block.end.4:
  br label %structured.block.end.1
}

define dllexport void @Quit() {
structured.entry.0:
  call void @__hike_impl_Quit()
  ret void
structured.block.end.1:
  ret void
structured.block.end.2:
  br label %structured.block.end.4
structured.after.return.3:
  br label %structured.block.end.2
structured.block.end.4:
  br label %structured.block.end.1
}

define i1 @__hike_impl_StartTextInput(i8* %window_arg.1) {
structured.entry.0:
  %window.2 = alloca i8*
  store i8* %window_arg.1, i8** %window.2
  %v3 = load i8*, i8** %window.2
  %v4 = call i1 @SDL_StartTextInput(i8* %v3)
  ret i1 %v4
structured.block.end.1:
  ret i1 false
structured.block.end.2:
  br label %structured.block.end.4
structured.after.return.3:
  br label %structured.block.end.2
structured.block.end.4:
  br label %structured.block.end.1
}

define dllexport i1 @StartTextInput(i8* %arg_0.1) {
structured.entry.0:
  %v2 = call i1 @__hike_impl_StartTextInput(i8* %arg_0.1)
  ret i1 %v2
structured.block.end.1:
  ret i1 false
structured.block.end.2:
  br label %structured.block.end.4
structured.after.return.3:
  br label %structured.block.end.2
structured.block.end.4:
  br label %structured.block.end.1
}

define i1 @__hike_impl_StopTextInput(i8* %window_arg.1) {
structured.entry.0:
  %window.2 = alloca i8*
  store i8* %window_arg.1, i8** %window.2
  %v3 = load i8*, i8** %window.2
  %v4 = call i1 @SDL_StopTextInput(i8* %v3)
  ret i1 %v4
structured.block.end.1:
  ret i1 false
structured.block.end.2:
  br label %structured.block.end.4
structured.after.return.3:
  br label %structured.block.end.2
structured.block.end.4:
  br label %structured.block.end.1
}

define dllexport i1 @StopTextInput(i8* %arg_0.1) {
structured.entry.0:
  %v2 = call i1 @__hike_impl_StopTextInput(i8* %arg_0.1)
  ret i1 %v2
structured.block.end.1:
  ret i1 false
structured.block.end.2:
  br label %structured.block.end.4
structured.after.return.3:
  br label %structured.block.end.2
structured.block.end.4:
  br label %structured.block.end.1
}

define i8* @__hike_impl_GetKeyName(i64 %key_arg.1) {
structured.entry.0:
  %key.2 = alloca i64
  store i64 %key_arg.1, i64* %key.2
  %v3 = load i64, i64* %key.2
  %v4 = call i8* @SDL_GetKeyName(i64 %v3)
  ret i8* %v4
structured.block.end.1:
  ret i8* zeroinitializer
structured.block.end.2:
  br label %structured.block.end.4
structured.after.return.3:
  br label %structured.block.end.2
structured.block.end.4:
  br label %structured.block.end.1
}

define dllexport i8* @GetKeyName(i64 %arg_0.1) {
structured.entry.0:
  %v2 = call i8* @__hike_impl_GetKeyName(i64 %arg_0.1)
  ret i8* %v2
structured.block.end.1:
  ret i8* zeroinitializer
structured.block.end.2:
  br label %structured.block.end.4
structured.after.return.3:
  br label %structured.block.end.2
structured.block.end.4:
  br label %structured.block.end.1
}

