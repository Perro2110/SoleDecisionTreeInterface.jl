using ProgressMeter

using SoleLogics: AbstractRelation
using SoleLogics: AbstractFormula
import SoleLogics: alphabet
import SoleLogics: initialworld

using SoleModels: CanonicalFeatureGeq, CanonicalFeatureGeqSoft, CanonicalFeatureLeq, CanonicalFeatureLeqSoft
using SoleModels: evaluate_thresh_decision, existential_aggregator, aggregator_bottom, aggregator_to_binary
# import SoleLogics: check
import SoleModels: check
using SoleModels: BoundedExplicitConditionalAlphabet

import SoleData: get_instance, instance, max_channel_size, channel_size, nattributes, nsamples, slice_dataset, _slice_dataset
import SoleData: dimensionality

import Base: eltype

############################################################################################

# Convenience functions
function grouped_featsnops2grouped_featsaggrsnops(
    grouped_featsnops::AbstractVector{<:AbstractVector{<:TestOperatorFun}}
)::AbstractVector{<:AbstractDict{<:Aggregator,<:AbstractVector{<:TestOperatorFun}}}
    grouped_featsaggrsnops = Dict{<:Aggregator,<:AbstractVector{<:TestOperatorFun}}[]
    for (i_feature, test_operators) in enumerate(grouped_featsnops)
        aggrsnops = Dict{Aggregator,AbstractVector{<:TestOperatorFun}}()
        for test_operator in test_operators
            aggregator = existential_aggregator(test_operator)
            if (!haskey(aggrsnops, aggregator))
                aggrsnops[aggregator] = TestOperatorFun[]
            end
            push!(aggrsnops[aggregator], test_operator)
        end
        push!(grouped_featsaggrsnops, aggrsnops)
    end
    grouped_featsaggrsnops
end

function grouped_featsaggrsnops2grouped_featsnops(
    grouped_featsaggrsnops::AbstractVector{<:AbstractDict{<:Aggregator,<:AbstractVector{<:TestOperatorFun}}}
)::AbstractVector{<:AbstractVector{<:TestOperatorFun}}
    grouped_featsnops = [begin
        vcat(values(grouped_featsaggrsnops)...)
    end for grouped_featsaggrsnops in grouped_featsaggrsnops]
    grouped_featsnops
end

function features_grouped_featsaggrsnops2featsnaggrs_grouped_featsnaggrs(features, grouped_featsaggrsnops)
    featsnaggrs = Tuple{<:AbstractFeature,<:Aggregator}[]
    grouped_featsnaggrs = AbstractVector{Tuple{<:Integer,<:Aggregator}}[]
    i_featsnaggr = 1
    for (feat,aggrsnops) in zip(features, grouped_featsaggrsnops)
        aggrs = []
        for aggr in keys(aggrsnops)
            push!(featsnaggrs, (feat,aggr))
            push!(aggrs, (i_featsnaggr,aggr))
            i_featsnaggr += 1
        end
        push!(grouped_featsnaggrs, aggrs)
    end
    featsnaggrs, grouped_featsnaggrs
end

function features_grouped_featsaggrsnops2featsnaggrs(features, grouped_featsaggrsnops)
    featsnaggrs = Tuple{<:AbstractFeature,<:Aggregator}[]
    i_featsnaggr = 1
    for (feat,aggrsnops) in zip(features, grouped_featsaggrsnops)
        for aggr in keys(aggrsnops)
            push!(featsnaggrs, (feat,aggr))
            i_featsnaggr += 1
        end
    end
    featsnaggrs
end

function features_grouped_featsaggrsnops2grouped_featsnaggrs(features, grouped_featsaggrsnops)
    grouped_featsnaggrs = AbstractVector{Tuple{<:Integer,<:Aggregator}}[]
    i_featsnaggr = 1
    for (feat,aggrsnops) in zip(features, grouped_featsaggrsnops)
        aggrs = []
        for aggr in keys(aggrsnops)
            push!(aggrs, (i_featsnaggr,aggr))
            i_featsnaggr += 1
        end
        push!(grouped_featsnaggrs, aggrs)
    end
    grouped_featsnaggrs
end

function check_initialworld(FD::Type{<:AbstractConditionalDataset}, initialworld, W)
    @assert isnothing(initialworld) || initialworld isa W "Cannot instantiate" *
        " $(FD) with worldtype = $(W) but initialworld of type $(typeof(initialworld))."
end

############################################################################################
# Active datasets comprehend structures for representing relation sets, features, enumerating worlds,
#  etc. While learning a model can be done only with active modal datasets, testing a model
#  can be done with both active and passive modal datasets.
#
abstract type ActiveFeaturedDataset{
    V<:Number,
    W<:AbstractWorld,
    FR<:AbstractFrame{W,Bool},
    FT<:AbstractFeature{V}
} <: AbstractConditionalDataset{W,AbstractCondition,Bool,FR} end

import SoleModels: featvaltype
import SoleModels: frame

featvaltype(::Type{<:ActiveFeaturedDataset{V}}) where {V} = V
featvaltype(d::ActiveFeaturedDataset) = featvaltype(typeof(d))

featuretype(::Type{<:ActiveFeaturedDataset{V,W,FR,FT}}) where {V,W,FR,FT} = FT
featuretype(d::ActiveFeaturedDataset) = featuretype(typeof(d))

function grouped_featsaggrsnops(X::ActiveFeaturedDataset)
    return error("Please, provide method grouped_featsaggrsnops(::$(typeof(X))).")
end

function grouped_metaconditions(X::ActiveFeaturedDataset)
    grouped_featsnops = grouped_featsaggrsnops2grouped_featsnops(grouped_featsaggrsnops(X))
    [begin
        (feat,[FeatMetaCondition(feat,op) for op in ops])
    end for (feat,ops) in zip(features(X),grouped_featsnops)]
end

function alphabet(X::ActiveFeaturedDataset)
    conds = vcat([begin
        thresholds = unique([
                X[i_sample, w, feature]
                for i_sample in 1:nsamples(X)
                    for w in allworlds(X, i_sample)
            ])
        [(mc, thresholds) for mc in metaconditions]
    end for (feature, metaconditions) in grouped_metaconditions(X)]...)
    C = FeatCondition{featvaltype(X),FeatMetaCondition{featuretype(X)}}
    BoundedExplicitConditionalAlphabet{C}(collect(conds))
end


# Base.length(X::ActiveFeaturedDataset) = nsamples(X)
# Base.iterate(X::ActiveFeaturedDataset, state=1) = state > nsamples(X) ? nothing : (get_instance(X, state), state+1)

function find_feature_id(X::ActiveFeaturedDataset, feature::AbstractFeature)
    id = findfirst(x->(Base.isequal(x, feature)), features(X))
    if isnothing(id)
        error("Could not find feature $(feature) in ActiveFeaturedDataset of type $(typeof(X)).")
    end
    id
end
function find_relation_id(X::ActiveFeaturedDataset, relation::AbstractRelation)
    id = findfirst(x->x==relation, relations(X))
    if isnothing(id)
        error("Could not find relation $(relation) in ActiveFeaturedDataset of type $(typeof(X)).")
    end
    id
end


# By default an active modal dataset cannot be minified
isminifiable(::ActiveFeaturedDataset) = false

include("passive-dimensional-dataset.jl")

include("dimensional-featured-dataset.jl")
include("featured-dataset.jl")

abstract type SupportingDataset{W<:AbstractWorld,FR<:AbstractFrame{W,Bool}} end

isminifiable(X::SupportingDataset) = false

worldtype(X::SupportingDataset{W}) where {W} = W

function display_structure(X::SupportingDataset; indent_str = "")
    out = "$(typeof(X))\t$((Base.summarysize(X)) / 1024 / 1024 |> x->round(x, digits=2)) MBs"
    out *= " ($(round(nmemoizedvalues(X))) values)\n"
    out
end

abstract type FeaturedSupportingDataset{V<:Number,W<:AbstractWorld,FR<:AbstractFrame{W,Bool}} <: SupportingDataset{W,FR} end


include("supported-featured-dataset.jl")

include("one-step-featured-supporting-dataset/main.jl")
include("generic-supporting-datasets.jl")

############################################################################################


@inline function check(
    p::Proposition{<:FeatCondition},
    X::AbstractConditionalDataset{W},
    i_sample::Integer,
    w::W,
) where {W<:AbstractWorld}
    c = atom(p)
    evaluate_thresh_decision(SoleModels.test_operator(c), X[i_sample, w, SoleModels.feature(c)], SoleModels.threshold(c))
end


# TODO fix: SyntaxTree{A} and SyntaxTree{B} are different, but they should not be.
# getindex(::AbstractDictionary{I, T}, ::I) --> T
# keys(::AbstractDictionary{I, T}) --> AbstractIndices{I}
# isassigned(::AbstractDictionary{I, T}, ::I) --> Bool
# TODO fix?
# hasformula(memo_structure::AbstractDict{F}, φ::SyntaxTree) where {F<:AbstractFormula} = haskey(memo_structure, SoleLogics.tree(φ))
hasformula(memo_structure::AbstractDict{F}, φ::AbstractFormula) where {F<:AbstractFormula} = haskey(memo_structure, φ)
hasformula(memo_structure::AbstractDict{SyntaxTree}, φ::AbstractFormula) = haskey(memo_structure, SoleLogics.tree(φ))

function check(
    φ::SoleLogics.AbstractFormula,
    X::AbstractConditionalDataset{W,<:AbstractCondition,<:Number,FR},
    i_sample::Integer;
    initialworld::Union{Nothing,W,AbstractVector{<:W}} = SoleLogics.initialworld(X, i_sample),
    # use_memo::Union{Nothing,AbstractVector{<:AbstractDict{<:F,<:T}}} = nothing,
    # use_memo::Union{Nothing,AbstractVector{<:AbstractDict{<:F,<:WorldSet{W}}}} = nothing,
    use_memo::Union{Nothing,AbstractVector{<:AbstractDict{<:F,<:WorldSet}}} = nothing,
    # memo_max_height = Inf,
) where {W<:AbstractWorld,T<:Bool,FR<:AbstractMultiModalFrame{W,T},F<:SoleLogics.AbstractFormula}

    @assert SoleLogics.isglobal(φ) || !isnothing(initialworld) "Cannot check non-global formula with no initialworld(s): $(syntaxstring(φ))."

    memo_structure = begin
        if isnothing(use_memo)
            Dict{SyntaxTree,WorldSet{W}}()
        else
            use_memo[i_sample]
        end
    end

    # forget_list = Vector{SoleLogics.FNode}()
    # hasmemo(::ActiveFeaturedDataset) = false
    # hasmemo(X)TODO

    # φ = normalize(φ) # TODO normalize formula and/or use a dedicate memoization structure that normalizes functions

    fr = frame(X, i_sample)

    # TODO avoid using when memo is nothing
    if !hasformula(memo_structure, φ)
        for ψ in unique(SoleLogics.subformulas(φ))
            # @show ψ
            # @show syntaxstring(ψ)
            # if height(ψ) > memo_max_height
            #     push!(forget_list, ψ)
            # end
            if !hasformula(memo_structure, ψ)
                tok = token(ψ)
                memo_structure[ψ] = begin
                    if tok isa SoleLogics.AbstractOperator
                        collect(SoleLogics.collateworlds(fr, tok, map(f->memo_structure[f], children(ψ))))
                    elseif tok isa Proposition
                        filter(w->check(tok, X, i_sample, w), collect(allworlds(fr)))
                    else
                        error("Unexpected token encountered in _check: $(typeof(tok))")
                    end
                end
            end
            # @show syntaxstring(ψ), memo_structure[ψ]
        end
    end

    # # All the worlds where a given formula is valid are returned.
    # # Then, internally, memoization-regulation is applied
    # # to forget some formula thus freeing space.
    # fcollection = deepcopy(memo(X))
    # for h in forget_list
    #     k = fhash(h)
    #     if hasformula(memo_structure, k)
    #         empty!(memo(X, k)) # Collection at memo(X)[k] is erased
    #         pop!(memo(X), k)    # Key k is deallocated too
    #     end
    # end

    ret = begin
        if isnothing(initialworld)
            length(memo_structure[φ]) > 0
        else
            initialworld in memo_structure[φ]
        end
    end

    return ret
end

############################################################################################

# function compute_chained_threshold(
#     φ::SoleLogics.AbstractFormula,
#     X::SupportedFeaturedDataset{V,W,FR},
#     i_sample;
#     use_memo::Union{Nothing,AbstractVector{<:AbstractDict{F,T}}} = nothing,
# ) where {V<:Number,W<:AbstractWorld,T<:Bool,FR<:AbstractMultiModalFrame{W,T},F<:SoleLogics.AbstractFormula}

#     @assert SoleLogics.isglobal(φ) "TODO expand code to specifying a world, defaulted to an initialworld. Cannot check non-global formula: $(syntaxstring(φ))."

#     memo_structure = begin
#         if isnothing(use_memo)
#             Dict{SyntaxTree,V}()
#         else
#             use_memo[i_sample]
#         end
#     end

#     # φ = normalize(φ) # TODO normalize formula and/or use a dedicate memoization structure that normalizes functions

#     fr = frame(X, i_sample)

#     if !hasformula(memo_structure, φ)
#         for ψ in unique(SoleLogics.subformulas(φ))
#             if !hasformula(memo_structure, ψ)
#                 tok = token(ψ)
#                 memo_structure[ψ] = begin
#                     if tok isa AbstractRelationalOperator && length(children(φ)) == 1 && height(φ) == 1
#                         featcond = atom(token(children(φ)[1]))
#                         if tok isa DiamondRelationalOperator
#                             # (L) f > a <-> max(acc) > a
#                             onestep_accessible_aggregation(X, i_sample, w, relation(tok), feature(featcond), existential_aggregator(test_operator(featcond)))
#                         elseif tok isa BoxRelationalOperator
#                             # [L] f > a  <-> min(acc) > a <-> ! (min(acc) <= a) <-> ¬ <L> (f <= a)
#                             onestep_accessible_aggregation(X, i_sample, w, relation(tok), feature(featcond), universal_aggregator(test_operator(featcond)))
#                         else
#                             error("Unexpected operator encountered in onestep_collateworlds: $(typeof(tok))")
#                         end
#                     else
#                         TODO
#                     end
#                 end
#             end
#             # @show syntaxstring(ψ), memo_structure[ψ]
#         end
#     end

#     # # All the worlds where a given formula is valid are returned.
#     # # Then, internally, memoization-regulation is applied
#     # # to forget some formula thus freeing space.
#     # fcollection = deepcopy(memo(X))
#     # for h in forget_list
#     #     k = fhash(h)
#     #     if hasformula(memo_structure, k)
#     #         empty!(memo(X, k)) # Collection at memo(X)[k] is erased
#     #         pop!(memo(X), k)    # Key k is deallocated too
#     #     end
#     # end

#     return memo_structure[φ]
# end


############################################################################################
