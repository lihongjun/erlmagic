-module(build_server).
-export([make_all/5]).

get_type("void") ->
    "";
get_type(T) ->
    hd(lists:reverse(T)).

param_base_type(T) ->
    Rval = case get_type(T) of
	"Blob" ->
	    "??Blob";
	"ChannelType" ->
	    "??ChannelType";
	"Color" ->
	    "??Color";
	"Geometry" ->
	    "Geometry";
	"Image" ->
	    "??Image";
	"ImageType" ->
	    "??ImageType";
	"MagickEvaluateOperator" ->
	    "??MagickEvaluateOperator";
	"PaintMethod" ->
	    "??PaintMethod";
	"Quantum" ->
	    "??Quantum";
	"StorageType" ->
	    "??StorageType";
	"bool" ->
	    "ERL_INT_VALUE";
	"char" ->
	    "ERL_INT_VALUE";
	"double" ->
	    "ERL_FLOAT_VALUE";
	"int" ->
	    "ERL_INT_VALUE";
	"std::string" ->
	    "erl_iolist_to_string";
	"std::string&" ->
	    "erl_iolist_to_string";
	"void" ->
	    "void";
	[] ->
	    "void";
	"std::list<Magick::Drawable>" ->
	    "??std::list<Magick::Drawable>";
	"Drawable" ->
	    "??Drawable";
	"GravityType" ->
	    "??GravityType";
	"CompositeOperator" ->
	    "??CompositeOperator";
	"DrawableAffine" ->
	    "??DrawableAffine";
	"NoiseType" ->
	    "??NoiseType";
	"unsigned" ->
	    "??unsigned"
    end,
    case string:substr(Rval, 1, 2) of
	"??" ->
	    %io:format("Rval = ~s~n", [Rval]),
	    throw({"Bad param", Rval});
	_ ->
	    Rval
    end.
	 
param_name(H) ->
    R = chp2:param_name(H),
    case R of
	nil ->
	    nil;
        [$*|_] ->
	    throw({"Bad param", R});
	_ ->
	    string:strip(string:strip(R, both, $&), both, $_)
    end.

make_param(Out_file, L, N, Param_fun) ->
    make_param(Out_file, L, N, Param_fun, [], []).

make_param(_, [], _, _, Acc1, Acc2) ->
    {lists:reverse(Acc1), lists:reverse(Acc2)};
make_param(Out_file, [H|L], N, Param_fun, Acc1, Acc2) ->
    Pname = param_name(H),
    T = get_type(chp2:param_type(H)),
    case param_base_type(chp2:param_type(H)) of 
	"void" ->
	    Acc21 = Acc2,
	    Acc11 = Acc1,
	    N_increment = 1;
	"Geometry" ->
	    Acc212 = [lists:flatten(Param_fun(Out_file, "double", "width", "ERL_FLOAT_VALUE", N))|Acc2],
	    Acc21 = [lists:flatten(Param_fun(Out_file, "double", "height", "ERL_FLOAT_VALUE", N+1))|Acc212],
	    N_increment = 2,
	    %Acc112 = ["Geometry:width" | Acc1],
	    %Acc11 = ["Geometry:height" | Acc112];
	    Acc11 = ["Geometry(width,height)" | Acc1];
	Pname_type ->
	    Acc21 = [lists:flatten(Param_fun(Out_file, T, Pname, Pname_type, N))|Acc2],
	    Acc11 = [Pname | Acc1],
	    N_increment = 1
    end,
    make_param(Out_file, L, N + N_increment, Param_fun, Acc11, Acc21).

bad_cmd(Command) ->
    lists:member(Command, ["compose", "read"]).


make_one(Row, Out_file, Body_fun, Param_fun, Bad_param_fun) ->
    %io:format("~p~n", [Row]),
    Command = chp2:name(Row),
    try 
	case bad_cmd(Command) of 
	    false ->
		{Param_names, Param_lines} = make_param(Out_file, chp2:param_vals(Row), 3, Param_fun), 
		Body_fun(Out_file, Command, Param_names, Param_lines);
	    true ->
		Bad_param_fun(Out_file, Command, "not implemented")
	end
    catch
	throw:{"Bad param", Reason} ->
	    Bad_param_fun(Out_file, Command, Reason)
    end.

make_all(F, Out_file, Body_fun, Param_fun, Bad_param_fun) ->
    MakeFunc =  fun(Out, Bf, Pf, Bpf) -> (fun(Row) -> make_one(Row, Out, Bf, Pf, Bpf) end) end,
    Func = MakeFunc(Out_file, Body_fun, Param_fun, Bad_param_fun),
    lists:foreach(Func, chp2:parse_file(F)).

	      
