geometry_type(1, crumpled_polygon).
geometry_type(2, cylinder).
geometry_type(3, flat_sheet).

area_stable(DeltaArea) :- DeltaArea < 15.

is_candy_wrapper(GeomCode, Velocity, DeltaArea) :-
    geometry_type(GeomCode, crumpled_polygon),
    Velocity > 5,
    \+ area_stable(DeltaArea).

analyze_stream(GeomCode, Velocity, DeltaArea, candy_waste, open_fast_gate) :-
    is_candy_wrapper(GeomCode, Velocity, DeltaArea), !.

analyze_stream(GeomCode, Velocity, _, plastic_bottle, open_main_chute) :-
    geometry_type(GeomCode, cylinder),
    Velocity > 2, !.

analyze_stream(_, _, _, unknown_target, log_to_delphi_ai).
