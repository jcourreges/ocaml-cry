(*
 * Copyright 2003-2009 Savonet team
 *
 * This file is part of Ocaml-cry.
 *
 * Ocaml-cry is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * Ocaml-cry is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Ocaml-cry; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 *)

(** Native implementation of the shout source protocols
  * for icecast and shoutcast. *)

(** {2 Description} 
  *
  * [Cry] implements the protocols used to connect and send source data to 
  * icecast2 and shoutcast servers. 
  *
  * It is a low-level implementation that minimally manages source
  * connections. In particular, it does not handle synchronisation, unlike
  * the main implementation libshout. Hence, the task of sending audio data
  * to the streaming server at real time rate is left to the application. *)

(** {2 Types and errors} *)

(** Possible errors. *)
type error =
  | Create of exn
  | Connect of exn
  | Close of exn
  | Write of exn
  | Read of exn
  | Busy 
  | Not_connected
  | Invalid_usage
  | Bad_answer of string option 
  | Http_answer of int*string*string

exception Error of error

(** Get a string explaining an error. *)
val string_of_error : exn -> string

(** Possible protocols. [Icy] is the (undocumented) shoutcast source protocol.
  * [Http] is the icecast2 source protocol. 
  * 
  * Ogg streaming is only possible with [Http]. Any headerless format,
  * (e.g. mpeg containers), should work with both protocols,
  * provided you set the correct content-type (mime) for the source. *)
type protocol = Icy | Http

(** Special type for content-type (mime) data. *)
type content_type

(** General mime type for ogg data. *)
val ogg_application : content_type

(** Mime type for audio data encapsulated using ogg. *)
val ogg_audio : content_type

(** Mime type for video data encapsulated using ogg. *)
val ogg_video : content_type

(** Mime type for mpeg audio data (mp3). *)
val mpeg : content_type

(** Create a mime type from a string (e.g. "audio/aacp") *)
val content_type_of_string : string -> content_type

(** Get the string representation of a mime type. *)
val string_of_content_type : content_type -> string

(** Type for a source connection. 
  *
  * [headers] is a hash table containing the headers.
  * See [connection] function for more details. *)
type connection =
  {
    mount        : string;
    user         : string;
    password     : string;
    host         : string;
    port         : int;
    content_type : content_type;
    protocol     : protocol;
    headers      : (string, string) Hashtbl.t
  }

(** Type for audio informations. Used for connection headers.
  * See [audio_info] function for more details. *)
type audio_info = (string, string) Hashtbl.t

(** Type for metadata values. *)
type metadata = (string,string) Hashtbl.t

(* Type for connection data *)
type connection_data =
  { connection      : connection;
    data_socket     : Unix.file_descr }

(** Type for the status of a handler. *)
type status = Connected of connection_data | Disconnected 

(** Type for the main handler. *)
type t

  (** {2 API} *)

(** Create a new handler.
  * 
  * [ipv6] is [false] by default.
  * [bind] is not used by default (system default). 
  * [timeout] is [30.] by default. *)
val create :
  ?ipv6:bool ->
  ?bind:string ->
  ?connection_timeout:float -> 
  ?timeout:float -> unit -> t

(** Get a handler's status *)
val get_status : t -> status

(** Get a handler's ICY capabilities.
  * For the [Http] protocol, this is always true.
  * For the [Icy] protocol, this is detected upon connecting. *)
val get_icy_cap : t -> bool

(** Get data associated with a connection. Use it only if you know
  * what you are doing. 
  *
  * Raises: [Error Not_connected] if not connected. *)
val get_connection_data : t -> connection_data

(** Create a new [audio_info] value,
  * filed with given values. *)
val audio_info :
  ?samplerate:int ->
  ?channels:int ->
  ?quality:float ->
  ?bitrate:int -> 
  unit -> audio_info

(** Create a new [connection] value
  * with default values. 
  *
  * [host] is ["localhost"] by default.
  * [password] is ["hackme"] by default.
  * [user] is ["source"] by default. Change [user] only if you know
  * what your are doing.
  * [protocol] is [Http] by default.
  * [port] is [8000] by default.
  * 
  * The list of preset headers for [Http] connections is:
  * ["User-Agent"], ["ice-name"], ["ice-genre"],
  * ["ice-url"], ["ice-public"], ["ice-audio-info"],
  * ["ice-description"].
  *
  * The list of preset headers for [Icy] connections is:
  * ["User-Agent"], ["icy-name"], ["icy-url"], ["icy-pub"], 
  * ["icy-genre"], ["icy-br"]. 
  *
  * Additionally, you can also add:
  * ["icy-irc"], ["icy-icq"] and ["icy-aim"] but these are not added
  * by this function. *)
val connection :
  ?user_agent:string ->
  ?name:string ->
  ?genre:string ->
  ?url:string ->
  ?public:bool ->
  ?audio_info:audio_info ->
  ?description:string ->
  ?host:string ->
  ?port:int ->
  ?password:string ->
  ?protocol:protocol ->
  ?user:string ->
  mount:string -> 
  content_type:content_type -> 
  unit -> connection

(** Connect a handler. *)
val connect : t -> connection -> unit

(** Update metadata on a handler. Useful only for non-ogg data format,
  * and if [icy_cap] is [true] for [Icy] connections. 
  *
  * For [Icy] protocol, the relevant metadata are only ["song"]
  * and ["url"]. 
  *
  * Raises: [Error Not_connected]
  * if not connected. *)
val update_metadata : ?charset:string -> t -> metadata -> unit

(** Manually update metadata on any source without necessarily
  * being connected to it for streaming.
  *
  * Optional [timeout] is [30.] by default.
  * 
  * Use it only if you know what you are doing ! *)
val manual_update_metadata :  
           host:string ->
           port:int ->
           protocol:protocol ->
           user:string ->
           password:string ->
           mount:string ->
           ?connection_timeout:float ->
           ?timeout:float ->
           ?headers:(string, string) Hashtbl.t ->
           ?ipv6:bool -> ?bind:string ->
           ?charset:string -> metadata -> 
           unit

(** Send data to a source connection. 
  *
  * Raises: [Error Not_connected]
  * if not connected. *)
val send : t -> string -> unit

(** Close a source connection. 
  * 
  * Raises: [Error Not_connected]
  * if not connected. *)
val close : t -> unit 

