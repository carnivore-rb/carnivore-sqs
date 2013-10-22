# Carnivore SQS

Provides SQS `Carnivore::Source`

# Usage

```ruby
require 'carnivore'
require 'carnivore-sqs'

Carnivore.configure do
  source = Carnivore::Source.build(
    :type => {
      :fog => {...},
      :queues => ['arn:aws:sqs:...']
    }
  )
end.start!
```

# Info
* Carnivore: https://github.com/carnivore-rb/carnivore
* Repository: https://github.com/carnivore-rb/carnivore-sqs
* IRC: Freenode @ #carnivore
