---
layout: post
title: How Readup Knows Whether or Not You've Read an Article
date: 2020-08-03
author: Jeff Camera
---
## Preface

This is Readup's first technical blog post so naturally it has to be about the read-tracker. Our entire platform is centered on article completion so the read-tracker, which determines whether or not someone has read an article, is absolutely foundational. Rather than just explain why things are they way they are I thought I'd try to walk you through the design process. My hope is that structuring the article this way will make it more interesting and easier to follow along. Code snippets are in PostgreSQL or TypeScript in a browser environment. If you're not a programmer feel free to skip the code sections or just read the comments within them. I tried to write this in such a way that it would make sense to non-programmers as well as those with a technical background.

## The Problem Domain

The initial inspiration for Readup was an idea that my co-founder, Bill, had for improving the quality of discourse in article comment sections: Make commenting a privilege for those who put in the time to actually read the article and keep everyone else out. Doing so might not result in a commenting utopia, but it seemed like a reasonable minimum requirement for participation that no one had bothered to implement.

From a technical perspective the next question is obvious: How could you know whether or not a person had read a given article? Let's walk through some options, roughly sorted from highest to lowest confidence level:

1. **Read the person's brain.** No APIs available yet. Keeping an eye on Neuralink.

2. **Quiz the reader on the content of the article.** A less invasive way to peek inside someone's brain. Bill originally pitched me the idea of keeping non-readers out of the comments back in the spring of 2016, almost a full year before [NRKbeta launched their quiz-to-comment Wordpress plugin](https://www.niemanlab.org/2017/03/this-site-is-taking-the-edge-off-rant-mode-by-making-readers-pass-a-quiz-before-commenting/). I don't remember if we ever discussed this approach at the time, but the biggest limiting factor would have been that a human would have to create the quiz questions for each article. We wanted our reading test to be completely automatic and generic enough that it could be used on any article on the web.

	Now, you could generate some questions programmatically. For example: "What was the *n*th word of the *n*th paragraph?" But such questions don't actually test comprehension, are annoying to answer and are just as easy to cheat as they are to create. I'm sure one could create better questions using natural language processing and content relevance algorithms but I still think it would be difficult to generate questions that are tied to the central plot or theme of the article and are not immediately solvable with a quick text search. Still sounds like a fun project though!

3. **Track the reader's eye movements with a camera.** Worth a mention because again it sounds like a fun project. Since there aren't any standard eye-tracking APIs we'd require live camera access which is of course a huge invasion of privacy. Come to think of it, a standard eye-tracking API might be even creepier. Either way we can rule this one out due to privacy concerns.

4. **Verify that the reader has scrolled to the bottom of the article.** You may have run into this when signing up for a new service or installing a new program. There's [a section in the InstallShield docs](https://docs.flexera.com/installshield23helplib/helplibrary/EulaScrollWatcher.htm) that explains how to require users to scroll through the End-User License Agreement before proceeding with the installation. There's also [some discussion on the UX Stack Exchange](https://ux.stackexchange.com/questions/35932/whats-the-best-way-to-make-a-user-read-terms-and-conditions-before-continuing-a) explaining why it's a bad idea.

	For our purposes the user experience concerns aren't an issue since articles, unlike most EULAs, are (ideally) written to be read. The main issue is that this check is absurdly easy to bypass. Press the End key or drag the scroll bar to the bottom and you're in. We're looking for something more comprehensive but unfortunately we're also nearing the bottom of our list.

5. **Verify that the reader has spent enough time on the page.** No instant bypass here, but time alone doesn't tell us much. The reader could have left to get a cup of coffee for 15 minutes and we wouldn't know the difference. We could look for periodic input or scroll events as a sign of activity but it still wouldn't tell us whether the reader is reading.

So we've reached the end of our list without a single solution. Options 1, 2 and 3 were each ruled out completely for different reasons but 4 and 5 merely failed to provide a robust enough solution on their own. Maybe we can combine them to create something better than the sum of their parts. Let's back up a bit first though. What does it actually mean to read an article? Or rather, to avoid the obvious metaphysical quandaries of such a question, how would we model it programmatically? We've got a hunch about the inputs (scroll position and time), but what about the outputs? Before we even start mucking around with an implementation, let's consider the broader architecture.

## The Data Model

Since any program that attempts to model a slice of reality is always battling against the aforementioned metaphysical quandaries it's useful to establish some axiomatic anchor points that we can tether ourselves to. Let's begin, working from the most general to most specific:

1. **It's impossible to really know whether a reader has read an article.** Again, no Neuralink API. What we're really looking to do is establish degrees of plausibility given the information and infrastructure available to us.

2. **You can't trust client input.** Given our information (scroll position and time) and infrastructure (the web) it's important to keep in mind that any client request received by the server is untrustworthy. It doesn't matter how fancy the client-side algorithms are. Any request can be forged.

3. **There must be a binary threshold somewhere.** We've acknowledged that our inputs are fuzzy, but ultimately we need to reduce the state of the relationship between any given reader to any given article to a binary value. Yes, reader *X* did read article *Y* or no, reader *X* did not read article *Y*.

4. **You can't un-read something you've read.** This might sound obvious but it's actually really helpful. Mutability increases the complexity of a system dramatically. If a piece of data must be mutable, the ramifications can at least be mitigated by narrowing the paths and limits of mutation.

Now keeping all that in mind, let's think about data structures. We know we need that binary threshold, so can that be the extent of it? How's this for a schema?

```sql
CREATE TABLE
	reader_article (
		reader_id  int REFERENCES reader (id),
		article_id int REFERENCES article (id),
		is_read    bool NOT NULL,
		PRIMARY KEY (
			reader_id,
			article_id
		)
	);
```

Needlessly complex it is not, but even at a glance it's missing some important information. One could imagine it might be nice to know when you read that article, but even if we change the name of the column from `is_read` to `date_read` and the data type from `bool` to `timestamp` we've still got some problems. What if a reader is half way through reading an hour long article and decides to take a break and finish it later? We need a way to store partial progress.

```sql
CREATE DOMAIN
	reading_progress
AS
	numeric
CHECK (
	VALUE <@ '[0, 1]'::numrange
);

CREATE TABLE
	reader_article (
		reader_id  int REFERENCES reader (id),
		article_id int REFERENCES article (id),
		progress   reading_progress NOT NULL,
		date_read  timestamp,
		PRIMARY KEY (
			reader_id,
			article_id
		)
	);
```

A definite improvement, but is it good enough? For some domains it might be, but this model is predicated on the assumption that reading is a strictly linear process, or at least it fails to distinguish between reading say the first 20% or last 20% of an article. Or how about the first 5% of each of the first 10 paragraphs? Skimming might not count as reading but it's a wide-spread behavior that we would fail to capture. What we really want to know is which parts of an article a reader has read. Let's get crazy and see what it would take to track whether each individual word has been read or not. We could of course zoom in even further to individual morphemes or characters but let's not get too carried away.

```sql
CREATE DOMAIN
	word_index
AS
	int
CHECK (
	VALUE >= 0
);

CREATE TABLE
	word (
		article_id int REFERENCES article (id),
		index      word_index,
		PRIMARY KEY (
			article_id,
			index
		)
	);

CREATE TABLE
	reader_word (
		reader_id  int REFERENCES reader (id),
		article_id int,
		index      word_index,
		date_read  timestamp NOT NULL,
		PRIMARY KEY (
			reader_id,
			article_id,
			index
		),
		FOREIGN KEY (
			article_id,
			index
		)
		REFERENCES
			word (
				article_id,
				index
			)
	);
```

Well, it's pretty normalized! It's also completely horrifying. First there's the storage concerns. We're looking at thousands, perhaps tens of thousands, of rows required per article and then potentially an equal amount per reader per article. Then there's the computation. One could imagine that we might want to know how many readers have read article *X*, but without caching that value we'd constantly be aggregating each word every reader has read in order to answer that question. I think some optimization is justified and luckily we now have an excess of information on our hands. Would we ever really care that the 101st word of an article was read 10 milliseconds after the 100th? I think it's safe to say we can dial that resolution back a bit. In order to optimize, let's first take a look at some sample data using that model to see if we notice any patterns.

```sql
-- Retrieve the reading progress for reader 7 on article 8.
SELECT
	word.index,
	reader_word.date_read
FROM
	word
	LEFT JOIN reader_word ON
		reader_word.reader_id = 7 AND
		reader_word.article_id = word.article_id AND
		reader_word.index = word.index
WHERE
	word.article_id = 8
ORDER BY
	word.index;

| index | date_read               |
|-------|-------------------------|
|   0   | 2020-01-01T12:00:00.000 |
|   1   | 2020-01-01T12:00:00.326 |
|   2   | 2020-01-01T12:00:00.652 |
|   3   | 2020-01-01T12:00:01.304 |
|   4   | 2020-01-01T12:00:01.630 |
|   5   | 2020-01-01T12:00:01.956 |
|   6   | 2020-01-01T12:00:02.282 |
|   7   | NULL                    |
|   8   | NULL                    |
|   9   | NULL                    |
|   10  | 2020-01-01T12:00:04.000 |
|   11  | 2020-01-01T12:00:04.326 |
|   12  | NULL                    |
|   13  | NULL                    |
|   14  | 2020-01-01T12:00:05.000 |
|   15  | NULL                    |
|   16  | NULL                    |
|   17  | NULL                    |
|   18  | 2020-01-01T12:00:06.000 |
|   19  | NULL                    |
```

Twenty words is a small sample size but we can make it work for this analysis. You can picture the same pattern of timestamps and nulls spread over a 2,000 word article or just imagine a 20 word sentence being read on a Tamagotchi. Either way we've got a cluster of reading at the start followed by some skimming to the end. We've already established that we don't care too much about knowing the exact millisecond that each word has been read, so given that, how can we compress the rest of the information into a more manageable structure? If we replace the timestamps with any non-null constant (we'll use `TRUE` in the following example) then all we have is a sequence of binary values. Let's represent this sequence as an array instead of a set. Since array elements have an intrinsic index we can ditch the `index` column in addition to the timestamp value.

```sql
{TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, NULL, NULL, NULL, TRUE, TRUE, NULL, NULL, TRUE, NULL, NULL, NULL, TRUE, NULL}
```

Looking better, but still pretty redundant. Since we only have two possible values in our sequence the only information we need to capture is how many of each value are stored in contiguous clusters. Let's count them up.

```sql
{7, 3, 2, 2, 1, 3, 1, 1}
```

That's seven `TRUE`s followed by three `NULL`s followed by two `TRUE`s followed by two `NULL`s followed by one `TRUE` followed by three `NULL`s followed by one `TRUE` followed by one `NULL`. Or wait, does that sequence start with seven `NULL`s? What if the reader skips the first words of the article? We need some way to indicate whether we're counting clusters of words that have been read or not read. Luckily for us we can represent that information while still just using an array of integers by utilizing the number's sign.

```sql
{7, -3, 2, -2, 1, -3, 1, -1}
```

That's it! That's the reading progress for reader 7 on article 8 condensed into a single value. Positive numbers represent clusters of words that have been read and negative numbers represent clusters of words that have not been read. Storing arrays in a database column always feels a little strange, and for good reason. But we did our due diligence by exploring the relational modeling of the data and I believe we made the case for using an array instead due to our practical concerns about storage and computational complexity.

You might point out that running the aggregate calculations on this array column could be even more expensive than doing the same over the word tables. But since we dropped the timestamps for individual words we must go back to using a nullable `date_read` column to capture the one timestamp that we do care about which will make counting reads a breeze. Let's update the previous `reader_article` table but change the underlying data type and check expression for the `reading_progress` domain with a tailored integer array instead.

```sql
/*
This might look a little crazy compared to the previous examples but we've got
some more extensive checking to do to ensure our array contains valid elements.
This function checks each array element to ensure that no values are null or
equal to zero and that the current element's sign is the inverse of that of the
previous element if present.

The call to coalesce ensures that the array contains at least one value.

The CHECK portion of the DOMAIN definition can only contain an expression which
is why we need to create a separate function instead of just inlining a
subquery.
*/
CREATE FUNCTION
	is_reading_progress_valid(
		reading_progress int[]
	)
RETURNS
	bool
LANGUAGE
	sql
IMMUTABLE
AS $$
	SELECT
		coalesce(
			every(validation_check.element_is_valid),
			FALSE
		)
	FROM
		(
			SELECT
				(
					progress_element.value IS NOT NULL AND
					progress_element.value != 0 AND
					CASE
						sign(
							lag(progress_element.value) OVER (
								ORDER BY
									progress_element.ordinality
							)
						)
					WHEN 1 THEN
						progress_element.value < 0
					WHEN -1 THEN
						progress_element.value > 0
					ELSE
						TRUE
					END
				) AS element_is_valid
			FROM
				unnest(
					is_reading_progress_valid.reading_progress
				)
				WITH ORDINALITY
				AS
					progress_element (
						value,
						ordinality
					)
		) AS validation_check;
$$;

CREATE DOMAIN
	reading_progress
AS
	int[]
CHECK (
	is_reading_progress_valid(VALUE)
);

CREATE TABLE
	reader_article (
		reader_id  int REFERENCES reader (id),
		article_id int REFERENCES article (id),
		progress   reading_progress NOT NULL,
		date_read  timestamp,
		PRIMARY KEY (
			reader_id,
			article_id
		)
	);
```

So is this it? Are we finally done with this data model? It's looking pretty solid, but the keen among you might have realized that while the sample data with 20 words looked nice and tidy we're still in a position where we could end up with a massive array with a length equal to the number of words in the article. Imagine a reader read every other word of a 10,000 word article. The reading progress array would look like this: `{1, -1, 1, -1, 1, -1...}`. The pattern would continue all the way up to the 10,000th element but would nevertheless satisfy our validation function.

This might look like a bug but I'd argue that it's actually a feature. Could a human even read in such a way that would generate that crazy reading progress array or did we just spot our first bot or malicious reader? Well that depends on the implementation. What a perfect segue!

## The Implementation

Let's circle back to our inputs (scroll position and time) and our execution environment (web browser) and see what we can do to color in our data model. We've already established that there's no event that will fire when a reader reads a word of an article so we're going to have to start making some assumptions. Requiring a reader to press a key or tap a button to indicate that they're reading would be a terrible user experience so we'll have to just assume that the reader is reading the text on their screen. Web pages are just structured text documents so that shouldn't be too difficult, right?

Well if you randomly sample even just a handful of articles from different publishers you might notice that the actual text content of the article is often only a small part of the web page document. There is a lot of noise, not just in the visual representation but also in the markup. Determining which parts of the document comprise the actual article content is a complicated problem that we'll save for a future blog post which could easily be even longer than this one. For now let's assume that we know where the article text is within the document and use the following simplified model of the reading environment.

![Reading Environment Diagram](/assets/2020/08/reading-environment-diagram-1.svg)

Looking at that diagram it's plain to see what text is visible within the viewport but making that determination programmatically isn't going to be so easy. The first problem is that we can't just ask the browser about lines of text or individual words or characters. We can get the size and coordinates of the paragraph element rectangles using `Element.getBoundingClientRect` but we cannot peer any deeper than that. The CSS Object Model actually does have a limited notion of characters (via `first-letter` and `initial-letter`) and lines of text (via `first-line`) but there's no analog in the Document Object Model. We can read the text content of the paragraph as a string, but we'll have no idea where the line breaks are. Programmatically what we see looks more like this.

![Reading Environment Diagram](/assets/2020/08/reading-environment-diagram-2.svg)

Is this enough information? Well, kind of. We can calculate that 50% of the area of the first paragraph intersects with the viewport and we know what text each paragraph contains. Our data model is based on read and unread words so we could just start marking the second half of the words within the first paragraph as having been read. In order to do that the first thing we need to do is count the number of words in each paragraph. Easy enough, right? Not so fast.

Context is very important here. At the time of writing Readup consists entirely of two people, only one of whom is a developer, both from the United States. As a result of our small size and limited resources we're only going to be focusing on English text for the time being. This is important because although English speakers might take it as a given that words are separated by spaces this is not the case in every language. Check out this Stack Overflow question as an example: [How does Chrome decide what to highlight when you double-click Japanese text?](https://stackoverflow.com/questions/61672829/how-does-chrome-decide-what-to-highlight-when-you-double-click-japanese-text). The [Text boundaries & wrapping](https://r12a.github.io/scripts/tutorial/part5) section of [An Introduction to Writing Systems & Unicode](https://r12a.github.io/scripts/tutorial/index), cited in a comment on an answer to that question, also does a great job of illustrating the complexities of determining what a word even is. Text direction is another factor that can vary from language to language but again we're going to stick with the English rules of top-to-bottom, left-to-right for now.

As an aside, even though we're only designing for English, there are quite a few other languages that will work just fine without any extra effort. A reader recently [posted an article](https://readup.com/comments/newsweek-belgi/moeten-we-ons-opmaken-voor-een-ijskoude-oorlog-aan-de-polen-deel-1---newsweek-be) from a Belgian publisher written in Dutch. Thanks to a suggestion from the reader I was able to use Google Chrome's translation feature to translate the text and get credit for reading the article on Readup. The tracker measures slightly different word counts between the original Dutch and the English translation but the mapping between these two languages is close enough that it just works.

Acknowledging all those caveats, for our purposes a word is simply going to be defined as any contiguous grouping of one or more non-whitespace characters. This will be relatively quick to calculate and reason about and should work as a decent enough approximation.

```typescript
// we'll use a regular expression to match and count our "words"
function countWords(paragraphElement: HTMLElement) {
	return (paragraphElement.textContent.match(/\S+/g) ?? []).length;
}
// get references to our paragraph elements
const paragraphElements = Array.from(
	document.getElementsByTagName('p')
);
console.log(
	countWords(paragraphElements[0])
); // 24 words in the first paragraph
console.log(
	paragraphElements.reduce(
		(articleWordCount, paragraphElement) => (
			articleWordCount + countWords(paragraphElement)
		),
		0
	)
); // 122 words in the whole article
```

Our initial reading progress array for this article will be `{-122}` since each of the 122 words starts out as unread. Knowing now that our first paragraph has 24 words and remembering that half of it is visible within the viewport, we could divide that number by 2 and start reading at the 13th word: `{-12, 1, -109}`. Rinse and repeat. Of course if you go back and check you'll see that the 13th word isn't actually visible, though it is pretty close.

In order to know with absolute certainty that a given word is completely visible within the viewport we would have to essentially implement all the browser's text layout and rendering algorithms to determine the exact size and position of every character - no small task! And even if we did go through all that trouble, are we really prepared to implement variable read timing to account for the fact that different words take different amounts of time to read? Once again, it sounds like a fun project (I'd imagine you could get something usable by combining word length with prevalence statistics) but it would be needlessly complicated for our purposes. If we're prepared to say that each word will take the same amount of time to read then it also makes sense to treat those words as equally-sized fixed percentages of their containing paragraph.

So we could stop there, and I believe we'd have to if we were restricted from modifying the DOM, but we're not so we won't. We could get the most precise measurements of word positions by removing the text nodes from the paragraph elements and replacing them with individual span elements for each word. In doing so we could get bounding rectangles for every single word but this is performance prohibitive. Trust me, I've tried. For a 30 minute article we're talking about roughly 10,000 additional elements which caused very noticeable lag in web browsers. There is an alternative approach though thanks to `Element.getClientRects`. From [MDN](https://developer.mozilla.org/en-US/docs/Web/API/Element/getClientRects):

> Originally, Microsoft intended this method to return a TextRectangle object for each line of text. However, the CSSOM working draft specifies that it returns a DOMRect for each border box. For an inline element, the two definitions are the same. But for a block element, Mozilla will return only a single rectangle.

If only Microsoft had their way! How often do you get to say that when it comes to web standards? Thankfully we can still access this helpful functionality by replacing all the text nodes in each paragraph element with a single span element containing the text content. Alternatively we could change the `display` property to `inline` for each paragraph element but this would mess with our formatting quite a bit.

```typescript
// nest text within a span element so we can use Element.getClientRects
function nestTextWithinSpanElement(paragraphElement: HTMLElement) {
	// store the text
	const text = paragraphElement.textContent;
	// remove the existing child nodes
	while (paragraphElement.hasChildNodes()) {
		paragraphElement.firstChild.remove();
	}
	// create a new span element and assign the text to it
	const spanElement = document.createElement('span');
	spanElement.textContent = text;
	// append the span element to the paragraph element
	paragraphElement.append(spanElement);
}
// replace text nodes with span elements in each paragraph
paragraphElements.forEach(nestTextWithinSpanElement);
```

Now we're getting somewhere. If we call `Element.getClientRects` on any of those freshly minted span elements we get an array of `DOMRect`s containing the dimensions and coordinates of each line of text. Let's pause here for a minute though and consider what is actually gained from this little trick. We still don't know which words are on which lines, so is this really any better than the previous approach? For accuracy? Barely. You'll see in a moment that we'd start reading at the 16th word instead of the 13th which is more accurate but I don't think that's enough of an improvement to justify the additional complexity of worrying about individual lines of text.

What does justify the complexity, I'd argue, is improved visual debugging and the ability to reason about reading progress on a line level versus a paragraph or article level. The visual debugging is a fun party trick, but it's also crucial in helping to track down reading bugs. If you haven't realized it by now, we take reading very seriously. It's sacred, and bugs that result in readers not getting credit for articles they've read are considered critical. The execution environments are also an absolute nightmare. Every publisher and CMS has a different document structure with different scripts running in different browsers and web views on different devices. There will be an endless supply of compatibility bugs so the ability to enable high resolution visual debugging on the fly is an important asset. Being able to see exactly where the tracker thinks each line of text is versus just the entire paragraph gives us a much clearer picture of what's going on under the hood. Tap the button below to check it out!

<div id="com_readup_blog_post_debug_container" style="margin: 2em; text-align: center;">
	<button id="com_readup_blog_post_debug_button" style="padding: 1em;">Toggle Visual Debugging</button>
	<div id="com_readup_blog_post_script">
		<script>
			document
				.getElementById('com_readup_blog_post_debug_button')
				.addEventListener(
					'click',
					event => {
						event.stopPropagation();
						window.postMessage(
							{
								type: 'toggleVisualDebugging'
							},
							'*'
						);
					}
				);
		</script>
	</div>
</div>

Before we get to the reading loop where we'll start marking off words as having been read let's set up our client side data model to give some structure to all this information we're going to be gathering. We'll also create some additional helper functions to map our paragraph elements to `Paragraph` objects which will each contain an array of `Line` objects representing the individual lines of text. A nice feature of our reading progress array data structure is that we can store a single array representing the whole article in the database, easily split it up into smaller arrays when reading on the client and then recombine them to update the stored progress. We'll create and update reading progress arrays for each line and combine them on the fly whenever we want to send a snapshot of our progress to the server.

```typescript
// we'll keep track of the position and progress of each line of text
interface Line {
	borderBox: DOMRect,
	readingProgress: number[]
}
// paragraphs have references to the concrete element and the abstract lines
interface Paragraph {
	element: HTMLElement,
	lines: Line[]
}
// create line references for a given paragraph element
function createLines(paragraphElement: HTMLElement) {
	// take some measurements
	const
		clientRects = paragraphElement.firstElementChild.getClientRects(),
		lineCount = clientRects.length,
		wordCount = countWords(paragraphElement),
		minLineWordCount = Math.floor(wordCount / lineCount);
	// distribute the words evenly over the lines
	let remainingWordCount = wordCount % lineCount;
	return clientRects.map(
		clientRect => {
			let lineWordCount = minLineWordCount;
			if (remainingWordCount) {
				lineWordCount++;
				remainingWordCount--;
			}
			return {
				borderBox: clientRect,
				readingProgress: [-lineWordCount]
			};
		}
	);
}
// map our paragraph elements to paragraphs
const paragraphs = paragraphElements.map(
	paragraphElement => ({
		element: paragraphElement,
		lines: createLines(paragraphElement)
	})
);
```

Let's take a look at our reading model after mapping our paragraph elements.

![Reading Environment Diagram](/assets/2020/08/reading-environment-diagram-3.svg)

It was a lot of work getting to this point, but you can probably see how easy it's going to be to write the reading loop thanks to all that preparation. Let's wrap this up!

```typescript
/*
Read the next visible word. Return true if a word is read or if there are any
words remaining to be read, otherwise return false.
*/
function tryReadWord(lines: Line[]) {
	/*
	Search for any unfinished lines. We're reading from left to right so we only
	have to check the sign of the last element in the array.
	*/
	const unfinishedLines = lines.filter(
		line => line[line.length - 1] < 0
	);
	// return false if there is nothing left to read
	if (!unfinishedLines.length) {
		return false;
	}
	// find the first line that is visible within the viewport
	const readableLine = unfinishedLines.find(
		line => (
			line.borderBox.top > 0 &&
			line.borderBox.bottom < window.innerHeight
		)
	);
	// increment the progress array left to right if found
	if (readableLine) {
		const progress = readableLine.readingProgress;
		if (progress.length === 1) {
			progress.unshift(1);
		} else {
			progress[0]++;
		}
		if (progress[1] === -1) {
			progress.splice(1, 1);
		} else {
			progress[1]++;
		}
	}
	return true;
}
// create an array of lines from the paragraphs
const lines = paragraphs.reduce(
	(lines, paragraph) => lines.concat(paragraph.lines)
	[]
);
// set an interval to read a word every 200 ms (equal to 300 word per minute)
const readingInterval = setInterval(
	() => {
		// attempt to read a word and stop the loop if we're done
		if (
			!tryReadWord(lines)
		) {
			clearInterval(readingInterval);
		}
	},
	200
);
```

Let's let that run for 5 seconds on our example web page and see where we end up.

![Reading Environment Diagram](/assets/2020/08/reading-environment-diagram-4.svg)

And that's it! As the interval delegate continues to fire, the rest of the lines visible within the viewport will continue to be marked as read, as will those currently outside the viewport as the reader scrolls them into view. I think you might agree that initiating a request to the server every 200 ms to update the progress in the database would be a bit excessive. We can instead let the progress accumulate in memory on the client for a while and create another interval that will combine all the individual line reading progress arrays and send it off to the server every few seconds. (Readup currently does this every three seconds.)

Speaking of timing, how did we end up with that 200 ms [magic number](https://en.wikipedia.org/wiki/Magic_number_(programming)#Unnamed_numerical_constants) for our reading interval? 300 words per minute is a [commonly cited reading rate](https://digest.bps.org.uk/2019/06/13/most-comprehensive-review-to-date-suggests-the-average-persons-reading-speed-is-slower-than-commonly-thought/) but there is quite a bit of variance between studies. There is also a lot of debate about speed reading and the difference between reading and skimming. John F. Kennedy said he could read 1,200 words per minute but [Ronald Carver thought that was "bunk"](https://slate.com/news-and-politics/2000/02/the-1000-word-dash.html) based on his 1985 study: *How Good Are Some of the World's Best Readers?*. Carver's findings seem pretty convincing to us so to be on the safe side we've set the actual tracker rate to the upper limit of the fastest readers at a whopping 600 words per minute. On the flip side we use a lower limit rate of only 184 words per minute when estimating article length.

Another thing we'll have to keep in mind is that HTML documents are fluid by nature. At any point in time a reader can rotate their device or resize their browser window and the dimensions of our paragraph elements and every node within them can change to accommodate the new viewport dimensions. The text will be reflowed and the number of lines within each paragraph can change. There are events that fire under both those circumstances but any random DOM manipulation could also change the position of the article text since the last time we measured it so Readup has yet another interval running that periodically rechecks those measurements every three seconds just to be on the safe side.

There are countless other scenarios (such as restoring an existing reading progress array to resume reading) and necessary validation checks that are unaccounted for by the code samples in this article. In fact all of the code samples are simplified versions of the real thing with the exception of the database reading progress array validation check. The intent was to boil the functionality down to the basics so that you could hopefully get a sense of the core mechanics of the Readup tracker. Before we finish there's one last thing I want to circle back to.

## Cheating

Now that you hopefully have a pretty good understanding of how the system works, you've probably also got some ideas about how to cheat it. And you know what? They'd probably all work! So why go through all this trouble to build a system that can still be bypassed? There are quite a few reasons.

1. **This is about way more than just keeping non-readers out of the comment section.** We want to surface the best articles on the internet based on the deepest level of engagement possible. We want to capture all the bounces, all the skimming and all the deep reading and use that data to rank articles instead of relying on superficial "likes" and "upvotes" which are mostly just knee-jerk reactions to headlines. [A study conducted by researchers at Notre Dame University](https://ieeexplore.ieee.org/document/8026184) on Reddit voting behavior supports this assertion:

	 > We find that most readers do not read the article that they vote on, and that, in total, 73% of posts were rated (i.e., upvoted or downvoted) without first viewing the content.

	 And these researchers, [like Twitter](https://twitter.com/twittersupport/status/1270783537667551233), equate viewing an article with reading an article. What percentage of people who did bother to click the link to an article actually read it to completion? We can do better, people. We have to!

2. **You're really cheating yourself.** This one is pretty simple. You should want to read! [Reading is good for you](https://www.bustle.com/articles/68860-7-ways-reading-affects-the-brain-from-increased-empathy-to-feeling-metaphors). Cheating at reading is like [cheating your FitBit](https://www.youtube.com/watch?v=jPVA63MaegA). Sure, it's possible but it's also just pretty sad.

3. **This barrier probably isn't for you.** That's you the reader who is likely a programmer who cares about reading. I was initially surprised to see that the [source code](https://github.com/nrkbeta/nrkbetaquiz) for the NRKbeta quiz had no server-side validation. In fact all it does is hide the form element in the DOM. In a [follow-up article](https://www.niemanlab.org/2017/03/this-site-is-taking-the-edge-off-rant-mode-by-making-readers-pass-a-quiz-before-commenting/), a journalist from the publisher had this to say about it:

    > Grut acknowledged that the comment quiz was fairly easy to get around for people with technological experience. One of NRKbeta’s readers even posted a script to show others how to get around the quiz. Grut said the site had to tell them: “Guys, this is not for you. We know it’s easy to modify some code in your inspector…it’s for the people who approach our articles with the intent of just ranting before they even look at the article.”

	 They're still using the same quiz plug-in all these years later which is at least a partial testament to that approach.

4. **You can only get away with so much.** Even if you are cheating, you can only cheat so much. If we run a database query and see that a reader has read 3 hour long articles within a 5 minute time span we would know something is up. It would also look suspicious if someone appeared to be reading non-stop at a constant rate for 24-hours straight. Basically, although cheating is inevitable there are at least some patterns we could guard against if it ever becomes a big enough problem on the platform.

    Another potential approach might be to compare entire reading progress update streams to look for patterns that might emerge for different articles. Do readers always read at a constant rate or are there certain sections of certain articles that they might tend to read faster or slower which a reading bot would fail to emulate? This is pure speculation but it's something that I think would be very interesting to look at one day.

So yes, while it is possible to cheat there are some hard limits thanks to our server-side architecture and more importantly we hope that you find Readup to be a useful tool for keeping yourself honest and accountable. I can remember many instances where I had a visceral, negative reaction to an article's headline and proceeded to read it just so I could leave a scathing comment. However, what usually ends up happening is that taking the time to read takes the edge off. By the time I finish the article I'm often left with a positive or at least more nuanced impression of the author's point of view.

When reviewing this post Bill said I could include him in this part as well. We're both consistently, pleasantly surprised when the platform that we built and have been using for years still works on us. You don't always need to have your mind changed, often it's just enough to take the time to see things from someone else's perspective. You don't have to agree in order to have an understanding but understanding takes work. And that's the work that Readup incentivizes.