_ = require 'underscore'

_regexp = 
	ruleName: /%s/g
	ruleKey: /%([a-zA-Z]{1}([a-zA-Z0-9\-_]{1,})?)/g

Validator =
	options: 
		errorParser: null
	rules: {}
	
	# given a name and a rule, add the rule to rules cache
	addRule: (name, rule) ->
		@rules[name] = rule
	
	# given the rule's name, return whether it's a valid rule 
	# (it has to have both test & message properties)
	checkRule: (name) ->
		rule = @rules[name]
		if typeof name == 'string' and rule and typeof rule.test == 'function' and typeof rule.message == 'string'
			return true
		
		throw new Error name + ' is not a complete rule. A complete rule must contain both `test` function and `message` string.'
	
	# parses error messages
	# replaces %s with key name, %argName with rule.argName
	error: (rule, key, message, ruleArgs) ->
		unless message
			# no custom message passed
			message = @rules[rule].message
		return message.
			replace(_regexp.ruleName, key).
			replace(_regexp.ruleKey, (whole, first) =>
				if ruleArgs[first]
					return ruleArgs[first]
				else if @rules[rule][first]
					return @rules[rule][first]
				return whole
			)
	
	# perform the validation
	testInternal: (obj, rule, key) ->
		theRule = rule
		
		unless typeof rule == 'string'
			theRule = rule.rule
		
		if @checkRule(theRule) 
			# allow rules using other rules by appling @rules to `test` method context
			context = _.defaults @rules[theRule], @
			if @rules[theRule].test.call context, obj[key], rule
				return @error theRule, key, rule.message, rule
		
		return false
	
	validate: (obj, ruleset) ->
		errors = []
		for key, rule of ruleset
			# check if it's an array of rules
			if Array.isArray rule
				for nestedRule in rule
					testResult = @testInternal obj, nestedRule, key
					errors.push testResult if testResult
			
			# single rule
			else
				testResult = @testInternal obj, rule, key
				errors.push testResult if testResult
		
		return errors if errors.length
		return []

Validator.addRule 'required',
	message: "%s is requried"
	test: (str) ->
		return true unless str

Validator.addRule 'email',
	message: "%s must be a valid e-mail address"
	regex: ///^
	([\w\!\#$\%\&\'\*\+\-\/\=\?\^\`{\|\}\~]+\.)*
	[\w\!\#$\%\&\'\*\+\-\/\=\?\^\`{\|\}\~]+
	@
	((((([a-z0-9]{1}[a-z0-9\-]{0,62}[a-z0-9]{1})|[a-z])\.)+[a-z]{2,6})|(\d{1,3}\.){3}\d{1,3}(\:\d{1,5})?)$
	///i
	test: (str) ->
		return false unless str
		return not @regex.test str

Validator.addRule 'lengthBetween',
	message: "%s must be between %low and %high characters long"
	low: 0
	high: 5
	test: (str, rule) ->
		return false unless str
		return true unless typeof str == 'string'
		
		low = rule.low or @low
		high = rule.high or @high
		len = str.length
		
		return true unless low <= len <= high

Validator.addRule 'minLength',
	message: "%s must be at least %minLength characters long"
	minLength: 1
	test: (str, rule) ->
		minLength = rule?.minLength or @minLength
		return @rules.lengthBetween.test str, {low: minLength, high: Infinity}

Validator.addRule 'maxLength',
	message: "%s must be at most %maxLength characters long"
	maxLength: 1
	test: (str, rule) ->
		maxLength = rule?.maxLength or @maxLenght
		return @rules.lengthBetween.test str, {low: 0, high: maxLength}

Validator.addRule 'between',
	message: "%s must be between %low and %high"
	low: 0
	high: 0
	test: (str, rule) ->
		return false unless str
		
		str = parseInt(str, 10)
		low = rule.low or @low
		high = rule.high or @high
		
		return true unless low <= str <= high

Validator.addRule 'greaterThan',
	message: "%s must be greater than %than"
	than: 0
	test: (str, rule) ->
		than = rule.than or @than
		return @rules.between.test str, {low: than+1, high: Infinity}

Validator.addRule 'lowerThan',
	message: "%s must be lower than %than"
	than: 0
	test: (str, rule) ->
		than = rule.than or @than
		return @rules.between.test str, {low: -Infinity, high: than-1}

Validator.addRule 'nonNegative',
	message: "%s must be non-negative"
	test: (str) ->
		return @rules.between.test str, {low: -1, high: Infinity}

Validator.addRule 'integer',
	message: "%s must be an integer"
	test: (str) ->
		return str % 1 != 0

Validator.addRule 'match',
	message: "%s doesn't match the required pattern"
	pattern: //
	test: (str, rule) ->
		return false unless str
		
		pattern = rule.pattern or @pattern
		return true unless str.match pattern

Validator.addRule 'equals',
	message: "%s isn't '%to'"
	to: ""
	test: (str, rule) ->
		return false unless str
		
		to = rule.to or @to
		return true unless str == to

module.exports = Validator